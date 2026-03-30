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
    when(mockSpeechRecognition.dispose()).thenAnswer((_) => Future.value());
    await service.dispose();
  });

  // Helper: initialise the service with successful mocks.
  Future<void> initService() async {
    when(mockRecorder.open()).thenAnswer((_) async => const Success(null));
    when(mockModelDownload.ensureModelReady())
        .thenAnswer((_) async => const Success(assets));
    when(mockSpeechRecognition.initialize(assets))
        .thenAnswer((_) => Future.value());
    await service.initialize();
  }

  // Helper: set up stop → transcribe flow and collect stream emissions.
  Future<({List<String?> bibs, List<String> partials})> stopAndCollect(
      String? wavPath, String transcript) async {
    when(mockRecorder.stop()).thenAnswer((_) async => wavPath);
    if (wavPath != null) {
      when(mockSpeechRecognition.transcribe(wavPath))
          .thenAnswer((_) async => transcript);
    }

    final bibs = <String?>[];
    final partials = <String>[];
    service.bibNumbers.listen(bibs.add);
    service.partialResults.listen(partials.add);

    await service.stop();
    await pumpEventQueue();

    return (bibs: bibs, partials: partials);
  }

  group('VoiceRecognitionService', () {
    // ── Initialize ──────────────────────────────────────────────────────────

    group('initialize', () {
      test('returns Success when recorder opens and model downloads', () async {
        when(mockRecorder.open()).thenAnswer((_) async => const Success(null));
        when(mockModelDownload.ensureModelReady())
            .thenAnswer((_) async => const Success(assets));
        when(mockSpeechRecognition.initialize(assets))
            .thenAnswer((_) => Future.value());

        final result = await service.initialize();

        expect(result, isA<Success<void>>());
        verify(mockSpeechRecognition.initialize(assets)).called(1);
      });

      test('returns Failure when recorder fails to open', () async {
        when(mockRecorder.open()).thenAnswer((_) async => Failure(
              AppError(userMessage: 'Could not open audio recorder.'),
            ));

        final result = await service.initialize();

        expect(result, isA<Failure<void>>());
        verifyNever(mockModelDownload.ensureModelReady());
        verifyNever(mockSpeechRecognition.initialize(any));
      });

      test('returns Failure when model download fails', () async {
        when(mockRecorder.open()).thenAnswer((_) async => const Success(null));
        when(mockModelDownload.ensureModelReady()).thenAnswer((_) async =>
            Failure(AppError(userMessage: 'Could not load model.')));

        final result = await service.initialize();

        expect(result, isA<Failure<void>>());
        verifyNever(mockSpeechRecognition.initialize(any));
      });

      test('returns Failure when an exception is thrown', () async {
        when(mockRecorder.open()).thenThrow(Exception('unexpected'));

        final result = await service.initialize();

        expect(result, isA<Failure<void>>());
      });
    });

    // ── Start ───────────────────────────────────────────────────────────────

    group('start', () {
      test('delegates to recorder after successful initialize', () async {
        await initService();
        when(mockRecorder.start()).thenAnswer((_) => Future.value());

        await service.start();

        verify(mockRecorder.start()).called(1);
      });

      test('does nothing if not initialized', () async {
        final uninit = VoiceRecognitionService(
          recorder: mockRecorder,
          modelDownload: mockModelDownload,
          speechRecognition: mockSpeechRecognition,
          parser: parser,
        );
        await uninit.start();
        verifyNever(mockRecorder.start());
        when(mockRecorder.close()).thenAnswer((_) => Future.value());
        when(mockSpeechRecognition.dispose()).thenAnswer((_) => Future.value());
        await uninit.dispose();
      });
    });

    // ── Stop — no recording ─────────────────────────────────────────────────

    group('stop — no recording or not ready', () {
      test('emits null bib and empty transcript when no file recorded',
          () async {
        await initService();
        final r = await stopAndCollect(null, '');

        expect(r.bibs, [null]);
        expect(r.partials, ['']);
      });

      test('emits null when not initialized', () async {
        // Service never initialized — _ready is false.
        when(mockRecorder.stop()).thenAnswer((_) async => '/tmp/bib.wav');

        final bibs = <String?>[];
        final partials = <String>[];
        service.bibNumbers.listen(bibs.add);
        service.partialResults.listen(partials.add);

        await service.stop();
        await pumpEventQueue();

        expect(bibs, [null]);
        expect(partials, ['']);
      });
    });

    // ── Stop — valid transcripts ────────────────────────────────────────────

    group('stop — valid transcripts produce correct bib strings', () {
      setUp(() async => initService());

      test('simple digit-by-digit: "one two three four" → 1234', () async {
        final r = await stopAndCollect('/tmp/b.wav', 'one two three four');
        expect(r.bibs, ['1234']);
        expect(r.partials, ['one two three four']);
      });

      test('tens groups: "twenty three" → 23', () async {
        final r = await stopAndCollect('/tmp/b.wav', 'twenty three');
        expect(r.bibs, ['23']);
      });

      test('natural English: "one hundred and five" → 105', () async {
        final r = await stopAndCollect('/tmp/b.wav', 'one hundred and five');
        expect(r.bibs, ['105']);
      });

      test('leading zeros preserved: "zero zero zero one" → 0001', () async {
        final r = await stopAndCollect('/tmp/b.wav', 'zero zero zero one');
        expect(r.bibs, ['0001']);
      });

      test('tens + teens: "seventy ten" → 7010', () async {
        final r = await stopAndCollect('/tmp/b.wav', 'seventy ten');
        expect(r.bibs, ['7010']);
      });

      test('mixed: "forty seven zero six" → 4706', () async {
        final r = await stopAndCollect('/tmp/b.wav', 'forty seven zero six');
        expect(r.bibs, ['4706']);
      });
    });

    // ── Stop — ASR misrecognitions handled ──────────────────────────────────

    group('stop — ASR misrecognitions produce correct bibs', () {
      setUp(() async => initService());

      test('"a hundred and five" → 105', () async {
        final r = await stopAndCollect('/tmp/b.wav', 'a hundred and five');
        expect(r.bibs, ['105']);
      });

      test('"ten o four" → 1004', () async {
        final r = await stopAndCollect('/tmp/b.wav', 'ten o four');
        expect(r.bibs, ['1004']);
      });

      test('"three ow seven" → 307', () async {
        final r = await stopAndCollect('/tmp/b.wav', 'three ow seven');
        expect(r.bibs, ['307']);
      });

      test('"five zero zero too" → 5002', () async {
        final r = await stopAndCollect('/tmp/b.wav', 'five zero zero too');
        expect(r.bibs, ['5002']);
      });

      test('"for zero three zero" → 4030', () async {
        final r = await stopAndCollect('/tmp/b.wav', 'for zero three zero');
        expect(r.bibs, ['4030']);
      });
    });

    // ── Stop — fuzzy zero normalisation ─────────────────────────────────────

    group('stop — fuzzy zero normalisation in full pipeline', () {
      setUp(() async => initService());

      test('z-garble: "eighteen zer zero" → 1800', () async {
        final r = await stopAndCollect('/tmp/b.wav', 'eighteen zer zero');
        expect(r.bibs, ['1800']);
      });

      test('z-garble: "ninety nine zir one" → 9901', () async {
        final r = await stopAndCollect('/tmp/b.wav', 'ninety nine zir one');
        expect(r.bibs, ['9901']);
      });

      test('possessive: "eleven\'s zero five" → 1105', () async {
        final r = await stopAndCollect('/tmp/b.wav', "eleven's zero five");
        expect(r.bibs, ['1105']);
      });

      test('ambiguous fallback: "eight year year eight" → 8008', () async {
        final r =
            await stopAndCollect('/tmp/b.wav', 'eight year year eight');
        expect(r.bibs, ['8008']);
      });

      test('explicit sub: "one dire one dieu" → 1010', () async {
        final r = await stopAndCollect('/tmp/b.wav', 'one dire one dieu');
        expect(r.bibs, ['1010']);
      });
    });

    // ── Stop — invalid transcripts ──────────────────────────────────────────

    group('stop — invalid transcripts produce null', () {
      setUp(() async => initService());

      test('gibberish: "hello world"', () async {
        final r = await stopAndCollect('/tmp/b.wav', 'hello world');
        expect(r.bibs, [null]);
      });

      test('empty transcript', () async {
        final r = await stopAndCollect('/tmp/b.wav', '');
        expect(r.bibs, [null]);
      });

      test('only unrecognised words: "banana apple"', () async {
        final r = await stopAndCollect('/tmp/b.wav', 'banana apple');
        expect(r.bibs, [null]);
      });

      test('out of range: "ten thousand"', () async {
        final r = await stopAndCollect('/tmp/b.wav', 'ten thousand');
        expect(r.bibs, [null]);
      });
    });

    // ── Stop — multiple calls ───────────────────────────────────────────────

    group('stop — multiple sequential calls', () {
      setUp(() async => initService());

      test('each stop emits independently', () async {
        when(mockRecorder.stop()).thenAnswer((_) async => '/tmp/b.wav');
        when(mockSpeechRecognition.transcribe('/tmp/b.wav'))
            .thenAnswer((_) async => 'forty two');

        final bibs = <String?>[];
        service.bibNumbers.listen(bibs.add);
        service.partialResults.listen((_) {});

        await service.stop();
        await pumpEventQueue();

        when(mockSpeechRecognition.transcribe('/tmp/b.wav'))
            .thenAnswer((_) async => 'ninety nine');

        await service.stop();
        await pumpEventQueue();

        expect(bibs, ['42', '99']);
      });
    });

    // ── Dispose ─────────────────────────────────────────────────────────────

    group('dispose', () {
      test('closes the recorder and speech service', () async {
        when(mockRecorder.open()).thenAnswer((_) async => const Success(null));
        when(mockModelDownload.ensureModelReady())
            .thenAnswer((_) async => const Success(assets));
        when(mockSpeechRecognition.initialize(assets))
            .thenAnswer((_) => Future.value());
        when(mockRecorder.close()).thenAnswer((_) => Future.value());
        when(mockSpeechRecognition.dispose()).thenAnswer((_) => Future.value());

        await service.initialize();
        await service.dispose();

        verify(mockRecorder.close()).called(1);
        verify(mockSpeechRecognition.dispose()).called(1);
      });
    });
  });
}
