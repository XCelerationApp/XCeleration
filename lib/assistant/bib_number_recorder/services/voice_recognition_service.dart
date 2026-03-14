import 'dart:async';
import 'dart:convert';

import 'package:vosk_flutter/vosk_flutter.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/logger.dart';

/// Number-word building blocks for the Vosk grammar.
///
/// Vosk will only recognise these words. The spoken sequence is then parsed
/// into an integer by [parseNumberWords]. "hundred" and "thousand" extend the
/// ~28 developer-specified words so that bib numbers can be spoken both as
/// natural number words ("one hundred five" → 105) and as digit/chunk
/// sequences ("one zero five" → 105, "ten five" → 105).
const List<String> bibGrammar = [
  'zero', 'one', 'two', 'three', 'four', 'five',
  'six', 'seven', 'eight', 'nine', 'ten', 'eleven',
  'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
  'seventeen', 'eighteen', 'nineteen', 'twenty', 'thirty',
  'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety',
  'hundred', 'thousand',
  '[unk]',
];

/// URL for the small English Vosk model (~40 MB compressed).
///
/// On first [initialize], this is downloaded to the app's documents directory
/// and cached. Subsequent calls reuse the cached version automatically via
/// [ModelLoader.isModelAlreadyLoaded].
const String _modelUrl =
    'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip';

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
/// Integrates [vosk_flutter] to listen for spoken bib numbers and emit them
/// as integers via [bibNumbers]. No UI is wired up — this is a service layer
/// intended for manual smoke testing and future controller integration.
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
  final _vosk = VoskFlutterPlugin.instance();
  final _bibController = StreamController<int?>.broadcast();
  final _partialController = StreamController<String>.broadcast();

  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  /// Emits a recognised bib number (1–9999), or null when speech is detected
  /// but cannot be parsed as a valid bib number.
  Stream<int?> get bibNumbers => _bibController.stream;

  /// Emits the real-time partial (in-progress) recognition text as the user
  /// speaks. Useful for displaying live feedback in the UI.
  Stream<String> get partialResults => _partialController.stream;

  /// Initialises the Vosk model, recogniser, and microphone speech service.
  ///
  /// Downloads the model on first use (~40 MB) to the app's documents
  /// directory; subsequent calls reuse the cached version instantly.
  ///
  /// Throws [MicrophoneAccessDeniedException] internally — this method wraps
  /// that into a [Failure] so callers never need to catch exceptions.
  Future<Result<void>> initialize() async {
    try {
      final modelPath = await ModelLoader().loadFromNetwork(_modelUrl);

      _model = await _vosk.createModel(modelPath);
      _recognizer = await _vosk.createRecognizer(
        model: _model!,
        sampleRate: 16000,
        grammar: bibGrammar,
      );

      // initSpeechService requests microphone permission internally.
      // Throws MicrophoneAccessDeniedException if denied.
      _speechService = await _vosk.initSpeechService(_recognizer!);

      _speechService!.onResult().listen((resultJson) {
        final bib = _parseResult(resultJson);
        _bibController.add(bib);
      });

      _speechService!.onPartial().listen((partialJson) {
        try {
          final map = jsonDecode(partialJson) as Map<String, dynamic>;
          final partial = (map['partial'] as String?)?.trim() ?? '';
          _partialController.add(partial);
        } catch (e) {
          Logger.e('[VoiceRecognitionService.onPartial] $e');
        }
      });

      return const Success(null);
    } on MicrophoneAccessDeniedException {
      return Failure(const AppError(
        userMessage: 'Microphone permission is required for voice recognition.',
      ));
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
  Future<void> start() async => _speechService?.start();

  /// Stops microphone capture. Any audio buffered since the last result will
  /// be flushed, causing a final [bibNumbers] event to be emitted.
  Future<void> stop() async => _speechService?.stop();

  /// Releases all resources. The service must not be used after this call.
  Future<void> dispose() async {
    await _speechService?.dispose();
    await _recognizer?.dispose();
    _model?.dispose();
    await _bibController.close();
    await _partialController.close();
  }

  /// Parses a Vosk final-result JSON string and returns a bib number integer,
  /// or null if the text is absent or not a valid bib number.
  ///
  /// Vosk emits: `{"result": [...], "text": "twenty three"}`
  int? _parseResult(String resultJson) {
    try {
      final map = jsonDecode(resultJson) as Map<String, dynamic>;
      final text = (map['text'] as String?)?.trim() ?? '';
      return parseNumberWords(text);
    } catch (e) {
      Logger.e('[VoiceRecognitionService._parseResult] $e');
      return null;
    }
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
        .where((w) => w.isNotEmpty && w != '[unk]')
        // "hundred" / "thousand" act only as separators — skip them
        .where((w) => w != 'hundred' && w != 'thousand')
        .toList();

    if (words.isEmpty) return null;

    final chunks = <int>[];
    String? pendingTens; // a tens word waiting for an optional following ones

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
