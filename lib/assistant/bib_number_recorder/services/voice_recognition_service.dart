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
  })  : _recorder = recorder,
        _modelDownload = modelDownload,
        _speechRecognition = speechRecognition,
        _parser = parser;

  /// Wires up all concrete implementations with sensible defaults.
  factory VoiceRecognitionService.create() => VoiceRecognitionService(
        recorder: BibAudioRecorder(),
        modelDownload: ModelDownloadService(),
        speechRecognition: SpeechRecognitionService(),
        parser: const BibNumberParser(),
      );

  final IBibAudioRecorder _recorder;
  final IModelDownloadService _modelDownload;
  final ISpeechRecognitionService _speechRecognition;
  final BibNumberParser _parser;

  final _bibController = StreamController<int?>.broadcast();
  final _partialController = StreamController<String>.broadcast();

  bool _ready = false;

  @override
  Stream<int?> get bibNumbers => _bibController.stream;

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

    if (path == null || !_ready) {
      _bibController.add(null);
      _partialController.add('');
      return;
    }

    final transcript = await _speechRecognition.transcribe(path);
    _partialController.add(transcript);
    _bibController.add(_parser.parse(transcript));
  }

  @override
  Future<void> dispose() async {
    await _recorder.close();
    await _speechRecognition.dispose();
    await _bibController.close();
    await _partialController.close();
  }
}
