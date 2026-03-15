import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/bib_number_parser.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/i_bib_audio_recorder.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/i_model_download_service.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/i_speech_recognition_service.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/model_assets.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/voice_recognition_service.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';

import 'voice_recognition_service_test.mocks.dart';

@GenerateMocks([IBibAudioRecorder, IModelDownloadService, ISpeechRecognitionService])
void main() {
  setUpAll(() {
    provideDummy<Result<void>>(const Failure(AppError(userMessage: '')));
    provideDummy<Result<ModelAssets>>(const Failure(AppError(userMessage: '')));
  });

  late MockIBibAudioRecorder mockRecorder;
  late MockIModelDownloadService mockModelDownload;
  late MockISpeechRecognitionService mockSpeechRecognition;
  late BibNumberParser parser;
  late VoiceRecognitionService service;

  const assets = ModelAssets(
    modelDir: '/model',
    hotwordsPath: '/model/hotwords.txt',
  );

  setUp(() {
    mockRecorder = MockIBibAudioRecorder();
    mockModelDownload = MockIModelDownloadService();
    mockSpeechRecognition = MockISpeechRecognitionService();
    parser = const BibNumberParser();

    service = VoiceRecognitionService(
      recorder: mockRecorder,
      modelDownload: mockModelDownload,
      speechRecognition: mockSpeechRecognition,
      parser: parser,
    );
  });

  tearDown(() async {
    when(mockRecorder.close()).thenAnswer((_) => Future.value());
    await service.dispose();
  });

  group('VoiceRecognitionService', () {
    group('initialize', () {
      test('returns Success when recorder opens and model downloads', () async {
        when(mockRecorder.open()).thenAnswer((_) async => const Success(null));
        when(mockModelDownload.ensureModelReady())
            .thenAnswer((_) async => const Success(assets));

        final result = await service.initialize();

        expect(result, isA<Success<void>>());
      });

      test('returns Failure when recorder fails to open', () async {
        when(mockRecorder.open()).thenAnswer((_) async => Failure(
              AppError(userMessage: 'Could not open audio recorder.'),
            ));

        final result = await service.initialize();

        expect(result, isA<Failure<void>>());
        verifyNever(mockModelDownload.ensureModelReady());
      });

      test('returns Failure when model download fails', () async {
        when(mockRecorder.open()).thenAnswer((_) async => const Success(null));
        when(mockModelDownload.ensureModelReady()).thenAnswer((_) async =>
            Failure(AppError(userMessage: 'Could not load model.')));

        final result = await service.initialize();

        expect(result, isA<Failure<void>>());
      });
    });

    group('start', () {
      test('delegates to recorder after successful initialize', () async {
        when(mockRecorder.open()).thenAnswer((_) async => const Success(null));
        when(mockModelDownload.ensureModelReady())
            .thenAnswer((_) async => const Success(assets));
        when(mockRecorder.start()).thenAnswer((_) => Future.value());

        await service.initialize();
        await service.start();

        verify(mockRecorder.start()).called(1);
      });

      test('does nothing if not initialized', () async {
        await service.start();

        verifyNever(mockRecorder.start());
      });
    });

    group('stop', () {
      setUp(() async {
        when(mockRecorder.open()).thenAnswer((_) async => const Success(null));
        when(mockModelDownload.ensureModelReady())
            .thenAnswer((_) async => const Success(assets));
        await service.initialize();
      });

      test('emits null bib and empty transcript when no file recorded',
          () async {
        when(mockRecorder.stop()).thenAnswer((_) async => null);

        final bibs = <int?>[];
        final partials = <String>[];
        service.bibNumbers.listen(bibs.add);
        service.partialResults.listen(partials.add);

        await service.stop();
        await pumpEventQueue();

        expect(bibs, [null]);
        expect(partials, ['']);
      });

      test('emits parsed bib number from transcript', () async {
        when(mockRecorder.stop()).thenAnswer((_) async => '/tmp/bib.wav');
        when(mockSpeechRecognition.transcribe(assets, '/tmp/bib.wav'))
            .thenAnswer((_) async => 'twenty three');

        final bibs = <int?>[];
        final partials = <String>[];
        service.bibNumbers.listen(bibs.add);
        service.partialResults.listen(partials.add);

        await service.stop();
        await pumpEventQueue();

        expect(bibs, [23]);
        expect(partials, ['twenty three']);
      });

      test('emits null bib when transcript does not contain a valid number',
          () async {
        when(mockRecorder.stop()).thenAnswer((_) async => '/tmp/bib.wav');
        when(mockSpeechRecognition.transcribe(assets, '/tmp/bib.wav'))
            .thenAnswer((_) async => 'hello world');

        final bibs = <int?>[];
        service.bibNumbers.listen(bibs.add);
        service.partialResults.listen((_) {});

        await service.stop();
        await pumpEventQueue();

        expect(bibs, [null]);
      });

      test('emits null bib for empty transcript', () async {
        when(mockRecorder.stop()).thenAnswer((_) async => '/tmp/bib.wav');
        when(mockSpeechRecognition.transcribe(assets, '/tmp/bib.wav'))
            .thenAnswer((_) async => '');

        final bibs = <int?>[];
        service.bibNumbers.listen(bibs.add);
        service.partialResults.listen((_) {});

        await service.stop();
        await pumpEventQueue();

        expect(bibs, [null]);
      });
    });

    group('dispose', () {
      test('closes the recorder', () async {
        when(mockRecorder.open()).thenAnswer((_) async => const Success(null));
        when(mockModelDownload.ensureModelReady())
            .thenAnswer((_) async => const Success(assets));
        when(mockRecorder.close()).thenAnswer((_) => Future.value());

        await service.initialize();
        await service.dispose();

        verify(mockRecorder.close()).called(1);
      });
    });
  });
}
