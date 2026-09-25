import 'dart:async';

import 'package:xceleration/assistant/bib_number_recorder/services/bib_audio_recorder.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/bib_number_parser.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/i_bib_audio_recorder.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/i_model_download_service.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/i_speech_recognition_service.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/i_voice_recognition_service.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/model_download_service.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/speech_recognition_service.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/logger.dart';

/// [IVoiceRecognitionService] implementation.
///
/// Orchestrates [IBibAudioRecorder], [IModelDownloadService],
/// [ISpeechRecognitionService], and [BibNumberParser]. All collaborators are
/// constructor-injected for testability.
///
/// Use [VoiceRecognitionService.create()] for production; inject fakes for
/// tests.
class VoiceRecognitionService implements IVoiceRecognitionService {
  VoiceRecognitionService({
    required IBibAudioRecorder recorder,
    required IModelDownloadService modelDownload,
    required ISpeechRecognitionService speechRecognition,
    required BibNumberParser parser,
    bool Function(String bib)? isKnownBib,
  })  : _recorder = recorder,
        _modelDownload = modelDownload,
        _speechRecognition = speechRecognition,
        _parser = parser,
        _isKnownBib = isKnownBib;

  /// Wires up all concrete implementations with sensible defaults.
  factory VoiceRecognitionService.create(
          {bool Function(String bib)? isKnownBib}) =>
      VoiceRecognitionService(
        recorder: BibAudioRecorder(),
        modelDownload: ModelDownloadService(),
        speechRecognition: SpeechRecognitionService(),
        parser: const BibNumberParser(),
        isKnownBib: isKnownBib,
      );

  final IBibAudioRecorder _recorder;
  final IModelDownloadService _modelDownload;
  final ISpeechRecognitionService _speechRecognition;
  final BibNumberParser _parser;

  /// Whether a bib is on the race's roster, used to settle what was said
  /// when the words could be read more than one way.
  final bool Function(String bib)? _isKnownBib;

  final _bibController = StreamController<String?>.broadcast();
  final _partialController = StreamController<String>.broadcast();

  bool _ready = false;

  @override
  Stream<String?> get bibNumbers => _bibController.stream;

  @override
  Stream<String> get partialResults => _partialController.stream;

  @override
  Future<Result<void>> initialize() async {
    try {
      final openResult = await _recorder.open();
      if (openResult is Failure) return openResult;

      final modelResult = await _modelDownload.ensureModelReady();
      switch (modelResult) {
        case Success(:final value):
          await _speechRecognition.initialize(value);
          _ready = true;
        case Failure():
          return modelResult;
      }

      return const Success(null);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not initialise voice recognition.',
        originalException: e,
      ));
    }
  }

  @override
  Future<void> start() async {
    if (!_ready) return;
    await _recorder.start();
  }

  @override
  Future<void> stop() async {
    final path = await _recorder.stop();
    // Logger.d('[VoiceRecognition] stop() — recorder returned path: $path, ready: $_ready');

    if (path == null || !_ready) {
      // Logger.d('[VoiceRecognition] No recording or not ready → emitting null');
      _bibController.add(null);
      _partialController.add('');
      return;
    }

    final transcript = await _speechRecognition.transcribe(path);
    final bib = _choose(transcript);
    Logger.d('[VoiceRecognition] "$transcript" → $bib');

    _partialController.add(transcript);
    _bibController.add(bib);
  }

  /// The bib heard: the first reading of [transcript] that is on the roster
  /// ("one to three four" is 1234 if there is a 1234, else 134 if there is
  /// a 134), or the plain reading when none is. Another reading is only
  /// taken when a runner has that bib.
  String? _choose(String transcript) {
    final readings = _parser.candidates(transcript);
    final known = _isKnownBib;
    if (known != null) {
      for (final bib in readings) {
        // A spoken leading zero is kept: "oh nine" is bib 09, as printed,
        // not runner 9.
        if (known(bib)) return bib;
      }
    }
    return _parser.parse(transcript);
  }

  @override
  Future<void> dispose() async {
    await _recorder.close();
    await _speechRecognition.dispose();
    await _bibController.close();
    await _partialController.close();
  }
}
