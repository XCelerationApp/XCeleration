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
/// ~28 developer-specified words so that bib numbers up to 9999 can be spoken
/// naturally (e.g. "one thousand two hundred thirty four").
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
/// and cached. Subsequent calls reuse the cached model automatically via
/// [ModelLoader.isModelAlreadyLoaded].
const String _modelUrl =
    'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip';

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
/// await service.start();
/// // ... later ...
/// await service.stop();
/// await service.dispose();
/// ```
class VoiceRecognitionService {
  final _vosk = VoskFlutterPlugin.instance();
  final _bibController = StreamController<int?>.broadcast();

  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  /// Emits a recognised bib number (1–9999), or null when speech is detected
  /// but cannot be parsed as a valid bib number.
  Stream<int?> get bibNumbers => _bibController.stream;

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

  /// Stops microphone capture.
  Future<void> stop() async => _speechService?.stop();

  /// Releases all resources. The service must not be used after this call.
  Future<void> dispose() async {
    await _speechService?.dispose();
    await _recognizer?.dispose();
    _model?.dispose();
    await _bibController.close();
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

  /// Converts a space-separated English number-word sequence into an integer
  /// in the range 1–9999, or returns null if parsing fails.
  ///
  /// Examples:
  /// - `"twenty three"` → 23
  /// - `"one hundred twenty three"` → 123
  /// - `"nine thousand nine hundred ninety nine"` → 9999
  /// - `""` / `"[unk]"` / unrecognised words → null
  static int? parseNumberWords(String text) {
    if (text.isEmpty) return null;
    final words = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final value = _parseWordList(words);
    if (value == null || value < 1 || value > 9999) return null;
    return value;
  }

  /// Recursively reduces a word list to an integer value.
  static int? _parseWordList(List<String> words) {
    if (words.isEmpty) return 0;

    // "X thousand [rest]"
    final thousandIdx = words.indexOf('thousand');
    if (thousandIdx > 0) {
      final thousands = _parseWordList(words.sublist(0, thousandIdx));
      final rest = thousandIdx + 1 < words.length
          ? _parseWordList(words.sublist(thousandIdx + 1))
          : 0;
      if (thousands == null || rest == null) return null;
      return thousands * 1000 + rest;
    }

    // "X hundred [rest]"
    final hundredIdx = words.indexOf('hundred');
    if (hundredIdx > 0) {
      final hundreds = _parseWordList(words.sublist(0, hundredIdx));
      final rest = hundredIdx + 1 < words.length
          ? _parseWordList(words.sublist(hundredIdx + 1))
          : 0;
      if (hundreds == null || rest == null) return null;
      return hundreds * 100 + rest;
    }

    // Sum remaining words (handles tens + optional ones, e.g. "twenty three")
    int sum = 0;
    for (final word in words) {
      if (word == '[unk]') return null;
      final v = _wordValues[word];
      if (v == null) return null;
      sum += v;
    }
    return sum;
  }
}
