import 'dart:async';
import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';

/// Base URL for model files on Hugging Face.
const String _modelBaseUrl =
    'https://huggingface.co/csukuangfj/'
    'sherpa-onnx-zipformer-small-en-2023-06-26/resolve/main';

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
/// Hold-to-speak: call [start] when the button is pressed, [stop] when
/// released. [stop] records then recognises in one pass, emitting a single
/// event on [bibNumbers].
class VoiceRecognitionService {
  final _bibController = StreamController<int?>.broadcast();
  final _partialController = StreamController<String>.broadcast();
  final _recorder = FlutterSoundRecorder();

  sherpa.OfflineRecognizer? _recognizer;
  bool _recorderOpen = false;
  String? _recordingPath;

  /// Emits a recognised bib number (1–9999), or null when no valid number
  /// was heard. Emitted once per [stop] call.
  Stream<int?> get bibNumbers => _bibController.stream;

  /// Emits the raw transcript text after [stop] (before bib parsing).
  Stream<String> get partialResults => _partialController.stream;

  /// Initialises the recorder and sherpa-onnx offline model.
  ///
  /// Downloads model files (~28 MB) on first use; subsequent calls use cache.
  Future<Result<void>> initialize() async {
    try {
      await _recorder.openRecorder();
      _recorderOpen = true;

      sherpa.initBindings();

      final modelDir = await _ensureModelDownloaded();

      final config = sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          transducer: sherpa.OfflineTransducerModelConfig(
            encoder: p.join(modelDir, 'encoder-epoch-99-avg-1.int8.onnx'),
            decoder: p.join(modelDir, 'decoder-epoch-99-avg-1.int8.onnx'),
            joiner: p.join(modelDir, 'joiner-epoch-99-avg-1.int8.onnx'),
          ),
          tokens: p.join(modelDir, 'tokens.txt'),
          numThreads: 2,
          debug: false,
        ),
        decodingMethod: 'greedy_search',
      );

      _recognizer = sherpa.OfflineRecognizer(config);
      return const Success(null);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not initialise voice recognition.',
        originalException: e,
      ));
    }
  }

  /// Starts recording audio to a temp WAV file.
  Future<void> start() async {
    if (_recognizer == null || !_recorderOpen) return;

    final tmp = await getTemporaryDirectory();
    _recordingPath = p.join(tmp.path, 'bib_recording.wav');

    final existing = File(_recordingPath!);
    if (existing.existsSync()) existing.deleteSync();

    await _recorder.startRecorder(
      toFile: _recordingPath,
      codec: Codec.pcm16WAV,
      sampleRate: 16000,
      numChannels: 1,
    );
  }

  /// Stops recording, runs recognition, and emits on [bibNumbers].
  Future<void> stop() async {
    final stoppedPath = await _recorder.stopRecorder();
    final path = stoppedPath ?? _recordingPath;
    _recordingPath = null;

    if (path == null || !File(path).existsSync()) {
      _bibController.add(null);
      _partialController.add('');
      return;
    }

    await _recognizeFile(path);
  }

  /// Releases all resources.
  Future<void> dispose() async {
    if (_recorderOpen) {
      await _recorder.closeRecorder();
      _recorderOpen = false;
    }
    _recognizer?.free();
    await _bibController.close();
    await _partialController.close();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _recognizeFile(String path) async {
    if (_recognizer == null) {
      _bibController.add(null);
      return;
    }

    final wave = sherpa.readWave(path);
    if (wave.samples.isEmpty) {
      _bibController.add(null);
      _partialController.add('');
      return;
    }

    final stream = _recognizer!.createStream();
    try {
      stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);
      _recognizer!.decode(stream);

      final rawResult = _recognizer!.getResult(stream).text.trim().toLowerCase();
      _partialController.add(rawResult);

      _bibController.add(parseNumberWords(rawResult));
    } finally {
      stream.free();
    }
  }

  /// Downloads model files if not already cached.
  Future<String> _ensureModelDownloaded() async {
    final support = await getApplicationSupportDirectory();
    final modelDir = p.join(
      support.path,
      'sherpa_onnx',
      'sherpa-onnx-zipformer-small-en-2023-06-26',
    );

    final requiredFiles = [
      'encoder-epoch-99-avg-1.int8.onnx',
      'decoder-epoch-99-avg-1.int8.onnx',
      'joiner-epoch-99-avg-1.int8.onnx',
      'tokens.txt',
    ];

    final allExist = requiredFiles.every(
      (f) => File(p.join(modelDir, f)).existsSync(),
    );
    if (allExist) return modelDir;

    await Directory(modelDir).create(recursive: true);
    final client = HttpClient();
    try {
      for (final filename in requiredFiles) {
        final dest = File(p.join(modelDir, filename));
        if (dest.existsSync()) continue;
        final request = await client.getUrl(Uri.parse('$_modelBaseUrl/$filename'));
        final response = await request.close();
        if (response.statusCode != 200) {
          throw Exception('Failed to download $filename (HTTP ${response.statusCode})');
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
  /// Supports digit-by-digit ("one two three four" → 1234), natural chunks
  /// ("twelve thirty four" → 1234), and full English ("one hundred and three"
  /// → 103, "one thousand two hundred and thirty four" → 1234).
  static int? parseNumberWords(String text) {
    if (text.isEmpty) return null;

    // Strip filler words; keep 'hundred'/'thousand' for natural-number path.
    final words = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w != 'and')
        .toList();

    if (words.isEmpty) return null;

    if (words.contains('hundred') || words.contains('thousand')) {
      return _parseNatural(words);
    }
    return _parseChunked(words);
  }

  /// Handles "X hundred [and] Y" and "X thousand [Y hundred [and] Z]".
  static int? _parseNatural(List<String> words) {
    int result = 0;
    int current = 0;
    for (final word in words) {
      if (word == 'thousand') {
        result += (current == 0 ? 1 : current) * 1000;
        current = 0;
      } else if (word == 'hundred') {
        current = (current == 0 ? 1 : current) * 100;
      } else {
        final v = _wordValues[word];
        if (v == null) return null;
        current += v;
      }
    }
    result += current;
    if (result < 1 || result > 9999) return null;
    return result;
  }

  /// Handles digit-by-digit ("one two three four" → 1234) and spoken chunks
  /// ("twelve thirty four" → 1234) by concatenating each group.
  static int? _parseChunked(List<String> words) {
    final chunks = <int>[];
    String? pendingTens;

    for (final word in words) {
      final v = _wordValues[word];
      if (v == null) return null;

      if (v >= 20 && v % 10 == 0) {
        if (pendingTens != null) chunks.add(_wordValues[pendingTens]!);
        pendingTens = word;
      } else if (pendingTens != null) {
        chunks.add(_wordValues[pendingTens]! + v);
        pendingTens = null;
      } else {
        chunks.add(v);
      }
    }

    if (pendingTens != null) chunks.add(_wordValues[pendingTens]!);
    if (chunks.isEmpty) return null;

    final joined = chunks.map((c) => c.toString()).join();
    final result = int.tryParse(joined);
    if (result == null || result < 1 || result > 9999) return null;
    return result;
  }
}
