import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/logger.dart';

/// Base URL for model archives on Hugging Face.
const String _modelBaseUrl =
    'https://huggingface.co/csukuangfj/'
    'sherpa-onnx-streaming-zipformer-en-20M-2023-02-17/resolve/main';

/// Number-word vocabulary used as hotwords for contextual biasing.
///
/// Sherpa-ONNX does not support hard grammar constraints; instead these words
/// are passed as hotwords to boost their recognition probability.
const List<String> bibHotwords = [
  'ZERO', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE',
  'SIX', 'SEVEN', 'EIGHT', 'NINE', 'TEN', 'ELEVEN',
  'TWELVE', 'THIRTEEN', 'FOURTEEN', 'FIFTEEN', 'SIXTEEN',
  'SEVENTEEN', 'EIGHTEEN', 'NINETEEN', 'TWENTY', 'THIRTY',
  'FORTY', 'FIFTY', 'SIXTY', 'SEVENTY', 'EIGHTY', 'NINETY',
  'HUNDRED', 'THOUSAND',
];

/// Map of all recognised number words to their integer values.
const Map<String, int> _wordValues = {
  'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4,
  'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
  'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13,
  'fourteen': 14, 'fifteen': 15, 'sixteen': 16, 'seventeen': 17,
  'eighteen': 18, 'nineteen': 19, 'twenty': 20, 'thirty': 30,
  'forty': 40, 'fifty': 50, 'sixty': 60, 'seventy': 70,
  'eighty': 80, 'ninety': 90,
};

/// Offline voice recognition service for bib numbers (1–9999).
///
/// Uses [sherpa_onnx] with a streaming zipformer model for cross-platform
/// (iOS + Android) offline recognition. Hotwords bias recognition toward
/// number words, then [parseNumberWords] converts the transcript to an int.
///
/// ## Typical usage
/// ```dart
/// final service = VoiceRecognitionService();
/// await service.initialize();
/// service.bibNumbers.listen((bib) => print('Got bib: $bib'));
/// service.partialResults.listen((text) => print('Partial: $text'));
/// await service.start();
/// // ... later ...
/// await service.stop();
/// await service.dispose();
/// ```
class VoiceRecognitionService {
  final _bibController = StreamController<int?>.broadcast();
  final _partialController = StreamController<String>.broadcast();
  final _recorder = AudioRecorder();

  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;
  StreamSubscription<Uint8List>? _audioSub;

  String _lastText = '';

  /// Emits a recognised bib number (1–9999), or null when speech is detected
  /// but cannot be parsed as a valid bib number.
  Stream<int?> get bibNumbers => _bibController.stream;

  /// Emits the real-time partial (in-progress) recognition text as the user
  /// speaks. Useful for displaying live feedback in the UI.
  Stream<String> get partialResults => _partialController.stream;

  /// Initialises the sherpa-onnx model and recogniser.
  ///
  /// Downloads the model on first use (~44 MB) to the app's support directory;
  /// subsequent calls reuse the cached version instantly.
  Future<Result<void>> initialize() async {
    try {
      sherpa.initBindings();

      final modelDir = await _ensureModelDownloaded();

      final config = sherpa.OnlineRecognizerConfig(
        feat: const sherpa.FeatureConfig(sampleRate: 16000, featureDim: 80),
        model: sherpa.OnlineModelConfig(
          transducer: sherpa.OnlineTransducerModelConfig(
            encoder: p.join(modelDir, 'encoder-epoch-99-avg-1.int8.onnx'),
            decoder: p.join(modelDir, 'decoder-epoch-99-avg-1.onnx'),
            joiner: p.join(modelDir, 'joiner-epoch-99-avg-1.onnx'),
          ),
          tokens: p.join(modelDir, 'tokens.txt'),
          modelType: 'zipformer',
          numThreads: 1,
          provider: 'cpu',
          debug: false,
        ),
        decodingMethod: 'modified_beam_search',
        maxActivePaths: 4,
        enableEndpoint: true,
        rule1MinTrailingSilence: 1.5,
        rule2MinTrailingSilence: 0.8,
        rule3MinUtteranceLength: 20.0,
      );

      _recognizer = sherpa.OnlineRecognizer(config);
      _stream = _recognizer!.createStream(hotwords: bibHotwords.join('\n'));

      return const Success(null);
    } catch (e, st) {
      Logger.e(
        '[VoiceRecognitionService.initialize] Failed to initialise',
        error: e,
        stackTrace: st,
      );
      return Failure(AppError(
        userMessage: 'Could not initialise voice recognition.',
        originalException: e,
      ));
    }
  }

  /// Starts microphone capture and recognition.
  Future<void> start() async {
    if (_recognizer == null || _stream == null) return;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _bibController.add(null);
      return;
    }

    _lastText = '';

    final audioStream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    _audioSub = audioStream.listen((Uint8List data) {
      final samples = _pcm16ToFloat32(data);
      _stream!.acceptWaveform(samples: samples, sampleRate: 16000);

      while (_recognizer!.isReady(_stream!)) {
        _recognizer!.decode(_stream!);
      }

      final result = _recognizer!.getResult(_stream!);
      final text = result.text.trim().toLowerCase();

      if (text != _lastText) {
        _lastText = text;
        _partialController.add(text);
      }

      if (_recognizer!.isEndpoint(_stream!)) {
        _onEndpoint(text);
        _recognizer!.reset(_stream!);
        _lastText = '';
      }
    });
  }

  /// Stops microphone capture. The final in-progress text is flushed and a
  /// [bibNumbers] event is emitted.
  Future<void> stop() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder.stop();

    // Flush any remaining audio and emit a final result
    if (_recognizer != null && _stream != null) {
      while (_recognizer!.isReady(_stream!)) {
        _recognizer!.decode(_stream!);
      }
      final result = _recognizer!.getResult(_stream!);
      final text = result.text.trim().toLowerCase();
      _onEndpoint(text);
      _recognizer!.reset(_stream!);
      _lastText = '';
    }
  }

  /// Releases all resources. The service must not be used after this call.
  Future<void> dispose() async {
    await _audioSub?.cancel();
    await _recorder.dispose();
    _stream?.free();
    _recognizer?.free();
    await _bibController.close();
    await _partialController.close();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _onEndpoint(String text) {
    if (text.isEmpty) return;
    final bib = parseNumberWords(text);
    _bibController.add(bib);
    _partialController.add('');
  }

  Float32List _pcm16ToFloat32(Uint8List bytes) {
    final values = Float32List(bytes.length ~/ 2);
    final data = ByteData.view(bytes.buffer);
    for (var i = 0; i < bytes.length; i += 2) {
      final short = data.getInt16(i, Endian.little);
      values[i ~/ 2] = short / 32768.0;
    }
    return values;
  }

  /// Downloads and extracts the model if not already cached.
  /// Returns the local directory path containing the model files.
  Future<String> _ensureModelDownloaded() async {
    final support = await getApplicationSupportDirectory();
    final modelDir = p.join(
      support.path,
      'sherpa_onnx',
      'sherpa-onnx-streaming-zipformer-en-20M-2023-02-17',
    );

    final requiredFiles = [
      'encoder-epoch-99-avg-1.int8.onnx',
      'decoder-epoch-99-avg-1.onnx',
      'joiner-epoch-99-avg-1.onnx',
      'tokens.txt',
    ];

    // Check if all required files exist
    final allExist = requiredFiles.every(
      (f) => File(p.join(modelDir, f)).existsSync(),
    );
    if (allExist) return modelDir;

    // Download each file individually
    await Directory(modelDir).create(recursive: true);
    final client = HttpClient();
    try {
      for (final filename in requiredFiles) {
        final dest = File(p.join(modelDir, filename));
        if (dest.existsSync()) continue;

        final uri = Uri.parse('$_modelBaseUrl/$filename');
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode != 200) {
          throw Exception('Failed to download $filename (${response.statusCode})');
        }
        await response.pipe(dest.openWrite());
      }
    } finally {
      client.close();
    }

    return modelDir;
  }

  /// Converts a spoken number-word sequence into an integer in the range
  /// 1–9999, or returns null if parsing fails.
  ///
  /// ## Algorithm — chunk concatenation
  ///
  /// "hundred" and "thousand" are treated as separators and ignored. The
  /// remaining words are grouped into natural chunks (a tens word optionally
  /// followed by a ones word), then each chunk's value is stringified and
  /// concatenated.
  ///
  /// Examples:
  /// - `"one two three four"` → [1][2][3][4] → "1234" → 1234
  /// - `"twelve thirty four"` → [12][34]     → "1234" → 1234
  /// - `"twenty three"`       → [23]         → "23"   → 23
  /// - `"one hundred five"`   → [1][5]       → "15"   → 15  ← note: "hundred" skipped
  /// - `"nine thousand nine hundred ninety nine"` → [9][9][99] → "9999" → 9999
  static int? parseNumberWords(String text) {
    if (text.isEmpty) return null;

    final words = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .where((w) => w != 'hundred' && w != 'thousand')
        .toList();

    if (words.isEmpty) return null;

    final chunks = <int>[];
    String? pendingTens;

    for (final word in words) {
      final v = _wordValues[word];
      if (v == null) return null; // unrecognised word

      if (v >= 20 && v % 10 == 0) {
        // Tens word (twenty … ninety): flush any previous lone tens
        if (pendingTens != null) {
          chunks.add(_wordValues[pendingTens]!);
        }
        pendingTens = word;
      } else if (pendingTens != null) {
        // Ones word (1–9) following a tens word: combine into one chunk
        chunks.add(_wordValues[pendingTens]! + v);
        pendingTens = null;
      } else {
        // Standalone digit (0–9) or teen (10–19): own chunk
        chunks.add(v);
      }
    }

    // Flush any trailing lone tens word (e.g. "forty" spoken alone → 40)
    if (pendingTens != null) {
      chunks.add(_wordValues[pendingTens]!);
    }

    if (chunks.isEmpty) return null;

    // Concatenate chunk values as digit strings → parse as integer
    final joined = chunks.map((c) => c.toString()).join();
    final result = int.tryParse(joined);
    if (result == null || result < 1 || result > 9999) return null;
    return result;
  }
}
