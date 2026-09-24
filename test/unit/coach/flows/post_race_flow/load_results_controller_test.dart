import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/controller/load_results_controller.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/services/post_frame_callback_scheduler.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/database/base_models.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

@GenerateMocks([MasterRace, IPostFrameCallbackScheduler])
import 'load_results_controller_test.mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _team = Team(teamId: 1, name: 'Eagles');

RaceRunner _runner(int id) => RaceRunner(
      raceId: 1,
      runner: Runner(
          runnerId: id, name: 'Runner $id', bibNumber: '$id', grade: 11),
      team: _team,
    );

LoadResultsController _buildController(
  MockMasterRace mockMasterRace,
  DevicesManager devices, {
  Future<String> Function(MasterRace)? encodeBibData,
  IPostFrameCallbackScheduler? scheduler,
}) {
  return LoadResultsController(
    masterRace: mockMasterRace,
    devices: devices,
    encodeBibData: encodeBibData,
    scheduler: scheduler,
  );
}

// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoadResultsController controller;
  late MockMasterRace mockMasterRace;
  late DevicesManager devices;

  setUp(() {
    mockMasterRace = MockMasterRace();
    // Coach browser device creates bibRecorder and raceTimer slots.
    devices = DevicesManager(DeviceName.coach, DeviceType.browserDevice);
    controller = _buildController(mockMasterRace, devices);
  });

  // =========================================================================
  group('LoadResultsController', () {
    // -----------------------------------------------------------------------
    group('loadResults', () {
      test('sets resultsLoaded to true and populates results on success',
          () async {
        final results = [
          RaceResult(
            raceId: 1,
            runner: _runner(1).runner,
            team: _team,
            place: 1,
            finishTime: const Duration(minutes: 10),
          ),
        ];
        when(mockMasterRace.results).thenAnswer((_) async => results);

        await controller.loadResults();

        expect(controller.resultsLoaded, isTrue);
        expect(controller.results, equals(results));
      });

      test('keeps resultsLoaded false when saved results list is empty',
          () async {
        when(mockMasterRace.results).thenAnswer((_) async => []);

        await controller.loadResults();

        expect(controller.resultsLoaded, isFalse);
        expect(controller.results, isEmpty);
      });

      test(
          'does not surface "Race is not finished" exception through error state',
          () async {
        when(mockMasterRace.results)
            .thenAnswer((_) async => throw Exception('Race is not finished'));

        await controller.loadResults();

        expect(controller.hasError, isFalse);
      });

      test('does not surface other exceptions through error state', () async {
        when(mockMasterRace.results)
            .thenAnswer((_) async => throw Exception('DB error'));

        await controller.loadResults();

        expect(controller.hasError, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    group('saveRaceResults', () {
      test('delegates to masterRace.saveResults on success', () async {
        final results = [
          RaceResult(
            raceId: 1,
            runner: _runner(1).runner,
            team: _team,
            place: 1,
            finishTime: const Duration(minutes: 10),
          ),
        ];
        when(mockMasterRace.saveResults(any)).thenAnswer((_) async {});

        await controller.saveRaceResults(results);

        verify(mockMasterRace.saveResults(results)).called(1);
      });

      test('rethrows exception from masterRace.saveResults on failure',
          () async {
        final results = [
          RaceResult(
            raceId: 1,
            runner: _runner(1).runner,
            team: _team,
            place: 1,
            finishTime: const Duration(minutes: 10),
          ),
        ];
        when(mockMasterRace.saveResults(any))
            .thenAnswer((_) async => throw Exception('DB error'));

        await expectLater(
          controller.saveRaceResults(results),
          throwsException,
        );
      });
    });

    // -----------------------------------------------------------------------
    group('saveCurrentResults', () {
      test('skips when hasBibConflicts is true', () async {
        controller.raceRunners = [_runner(1), 99];
        controller.timingChunks = [
          TimingChunk(id: 0, timingData: [TimingDatum(time: '10:00.0')]),
        ];
        controller.hasBibConflicts = true;

        await controller.saveCurrentResults();

        verifyNever(mockMasterRace.saveResults(any));
      });

      test('skips when hasTimingConflicts is true', () async {
        controller.raceRunners = [_runner(1)];
        controller.timingChunks = [
          TimingChunk(
            id: 0,
            timingData: [TimingDatum(time: '10:00.0')],
            conflictRecord: TimingDatum(
              time: 'MISSING_TIMES',
              conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
            ),
          ),
        ];
        controller.hasTimingConflicts = true;

        await controller.saveCurrentResults();

        verifyNever(mockMasterRace.saveResults(any));
      });

      test('skips when timingChunks is null', () async {
        controller.raceRunners = [_runner(1)];
        controller.timingChunks = null;

        await controller.saveCurrentResults();

        verifyNever(mockMasterRace.saveResults(any));
      });

      test('skips when raceRunners is null', () async {
        controller.timingChunks = [
          TimingChunk(id: 0, timingData: [TimingDatum(time: '10:00.0')]),
        ];
        controller.raceRunners = null;

        await controller.saveCurrentResults();

        verifyNever(mockMasterRace.saveResults(any));
      });

      test('saves results when no conflicts and matching data is present',
          () async {
        when(mockMasterRace.raceId).thenReturn(1);
        when(mockMasterRace.saveResults(any)).thenAnswer((_) async {});

        controller.raceRunners = [_runner(1)];
        controller.timingChunks = [
          TimingChunk(id: 0, timingData: [TimingDatum(time: '10:00.0')]),
        ];

        await controller.saveCurrentResults();

        verify(mockMasterRace.saveResults(any)).called(1);
      });

      test('saves every finisher in finish order in a single call', () async {
        // One call lets a reload replace earlier results as a whole rather
        // than being rejected runner by runner as duplicates.
        when(mockMasterRace.raceId).thenReturn(1);
        when(mockMasterRace.saveResults(any)).thenAnswer((_) async {});
        controller.raceRunners = [_runner(1), _runner(2)];
        controller.timingChunks = [
          TimingChunk(id: 0, timingData: [
            TimingDatum(time: '10:00.0'),
            TimingDatum(time: '10:05.0'),
          ]),
        ];

        await controller.saveCurrentResults();

        final saved = verify(mockMasterRace.saveResults(captureAny))
            .captured
            .single as List<RaceResult>;
        expect([for (final r in saved) r.place], [1, 2]);
      });

      test('refuses to save a time that cannot be read', () async {
        // It used to be saved as 0:00, making that runner the race winner.
        when(mockMasterRace.raceId).thenReturn(1);
        controller.raceRunners = [_runner(1), _runner(2)];
        controller.timingChunks = [
          TimingChunk(id: 0, timingData: [
            TimingDatum(time: '10:00.0'),
            TimingDatum(time: 'TBD'),
          ]),
        ];

        final error = await controller.saveCurrentResults();

        expect(error, isNotNull);
        expect(controller.hasError, isTrue);
        verifyNever(mockMasterRace.saveResults(any));
      });

      test('returns an error instead of silently skipping on a count mismatch',
          () async {
        controller.raceRunners = [_runner(1), _runner(2)];
        controller.timingChunks = [
          TimingChunk(id: 0, timingData: [TimingDatum(time: '10:00.0')]),
        ];

        final error = await controller.saveCurrentResults();

        expect(error, isNotNull);
        verifyNever(mockMasterRace.saveResults(any));
      });

      test('refuses to save a runner twice', () async {
        final runner = _runner(1);
        controller.raceRunners = [runner, runner];
        controller.timingChunks = [
          TimingChunk(id: 0, timingData: [
            TimingDatum(time: '10:00.0'),
            TimingDatum(time: '10:05.0'),
          ]),
        ];

        final error = await controller.saveCurrentResults();

        expect(error!.userMessage, contains('more than once'));
        verifyNever(mockMasterRace.saveResults(any));
      });

      test('returns an error while conflicts remain', () async {
        controller.hasBibConflicts = true;
        expect(await controller.saveCurrentResults(), isNotNull);
      });

      test('sets an error when saving fails', () async {
        when(mockMasterRace.raceId).thenReturn(1);
        when(mockMasterRace.saveResults(any))
            .thenAnswer((_) async => throw Exception('db error'));
        controller.raceRunners = [_runner(1)];
        controller.timingChunks = [
          TimingChunk(id: 0, timingData: [TimingDatum(time: '10:00.0')]),
        ];

        final error = await controller.saveCurrentResults();

        expect(error, isNotNull);
        expect(controller.hasError, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    group('containsBibConflicts', () {
      test('returns false when raceRunners is null', () {
        controller.raceRunners = null;
        expect(controller.containsBibConflicts(), isFalse);
      });

      test('returns false when raceRunners has no unresolved bib entries', () {
        controller.raceRunners = [_runner(1), _runner(2)];
        expect(controller.containsBibConflicts(), isFalse);
      });

      test('returns true when raceRunners contains an unresolved bib', () {
        // A String in the list is a bib number that still needs resolving.
        controller.raceRunners = [_runner(1), '99'];
        expect(controller.containsBibConflicts(), isTrue);
      });
    });

    // -----------------------------------------------------------------------
    group('containsTimingConflicts', () {
      test('returns false when timingChunks is null', () {
        controller.timingChunks = null;
        expect(controller.containsTimingConflicts(), isFalse);
      });

      test('returns false when all chunks have only confirmRunner conflicts',
          () {
        controller.timingChunks = [
          TimingChunk(
            id: 0,
            timingData: [TimingDatum(time: '10:00.0')],
            conflictRecord: TimingDatum(
              time: '10:30.0',
              conflict: Conflict(type: ConflictType.confirmRunner, offBy: 0),
            ),
          ),
        ];
        expect(controller.containsTimingConflicts(), isFalse);
      });

      test('returns true when a chunk has a missingTime conflict', () {
        controller.timingChunks = [
          TimingChunk(
            id: 0,
            timingData: const [],
            conflictRecord: TimingDatum(
              time: 'MISSING_TIMES',
              conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
            ),
          ),
        ];
        expect(controller.containsTimingConflicts(), isTrue);
      });

      test('returns true when a chunk has an extraTime conflict', () {
        controller.timingChunks = [
          TimingChunk(
            id: 0,
            timingData: [
              TimingDatum(time: '10:00.0'),
              TimingDatum(time: '11:00.0'),
            ],
            conflictRecord: TimingDatum(
              time: '11:00.0',
              conflict: Conflict(type: ConflictType.extraTime, offBy: 1),
            ),
          ),
        ];
        expect(controller.containsTimingConflicts(), isTrue);
      });
    });

    // -----------------------------------------------------------------------
    group('resetDevices', () {
      test('clears all state flags and collections', () async {
        controller = _buildController(
          mockMasterRace,
          devices,
          encodeBibData: (_) async => 'encoded',
        );

        // Set some state before reset
        controller.raceRunners = [_runner(1)];
        controller.timingChunks = [
          TimingChunk(id: 0, timingData: [TimingDatum(time: '10:00.0')]),
        ];
        controller.resultsLoaded = true;
        controller.hasBibConflicts = true;
        controller.hasTimingConflicts = true;

        await controller.resetDevices();

        expect(controller.resultsLoaded, isFalse);
        expect(controller.hasBibConflicts, isFalse);
        expect(controller.hasTimingConflicts, isFalse);
        expect(controller.results, isEmpty);
        expect(controller.timingChunks, isNull);
        expect(controller.raceRunners, isNull);
      });

      test('sets bibRecorder.data to the encoded value from stub encoder',
          () async {
        const encodedData = 'stub-encoded-data';
        controller = _buildController(
          mockMasterRace,
          devices,
          encodeBibData: (_) async => encodedData,
        );

        await controller.resetDevices();

        expect(devices.bibRecorder?.data, equals(encodedData));
      });
    });

    // -----------------------------------------------------------------------
    group('processReceivedData', () {
      testWidgets(
          'when bibRecorder data is null, shows error dialog without throwing',
          (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(builder: (ctx) {
              capturedContext = ctx;
              return const SizedBox();
            }),
          ),
        );

        // bibRecorder.data is null by default; only set raceTimer data
        devices.raceTimer!.data = '10:00.0,CR 0 10:30.0';

        await controller.processReceivedData(capturedContext);
        // Advance past the FToast notification duration (3 s)
        await tester.pump(const Duration(seconds: 4));

        expect(controller.hasError, isFalse);
        expect(controller.resultsLoaded, isFalse);
      });

      testWidgets(
          'when BibDecodeUtils returns Failure, sets error and does not proceed',
          (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(builder: (ctx) {
              capturedContext = ctx;
              return const SizedBox();
            }),
          ),
        );

        // Valid JSON but a List not a Map → FormatException → Failure
        devices.bibRecorder!.data = '[1, 2, 3]';
        devices.raceTimer!.data = '10:00.0,CR 0 10:30.0';

        await controller.processReceivedData(capturedContext);

        expect(controller.hasError, isTrue);
        verifyNever(mockMasterRace.getRaceRunnerByBib(any));
      });

      testWidgets(
          'marks the second occurrence of a duplicate bib as a conflict',
          (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(builder: (ctx) {
              capturedContext = ctx;
              return const SizedBox();
            }),
          ),
        );

        final runner1 = _runner(1);
        when(mockMasterRace.getRaceRunnerByBib('1'))
            .thenAnswer((_) async => runner1);

        // Bib "1" appears twice in the bib list
        const rawBibJson =
            '{"teams":["EAGLES"],"r":[["1","Runner 1",0,"11"],["1","Runner 1 Again",0,"11"]]}';
        // 2 timing records so lengths match
        const rawTiming = '10:00.0,11:00.0,CR 0 11:30.0';

        devices.bibRecorder!.data = rawBibJson;
        devices.raceTimer!.data = rawTiming;

        await controller.processReceivedData(capturedContext);

        expect(controller.raceRunners, isNotNull);
        expect(controller.raceRunners!.length, 2);
        expect(controller.raceRunners![0], isA<RaceRunner>());
        expect(controller.raceRunners![1], '1');
      });
    });

    // -----------------------------------------------------------------------
    group('processReceivedData — data integrity', () {
      Future<BuildContext> pumpContext(WidgetTester tester) async {
        late BuildContext ctx;
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        ));
        return ctx;
      }

      testWidgets('stops with an error when a finish time cannot be read',
          (tester) async {
        final ctx = await pumpContext(tester);
        when(mockMasterRace.getRaceRunnerByBib('1'))
            .thenAnswer((_) async => _runner(1));
        when(mockMasterRace.getRaceRunnerByBib('2'))
            .thenAnswer((_) async => _runner(2));
        devices.bibRecorder!.data =
            '{"teams":["EAGLES"],"r":[["1","R1",0,"11"],["2","R2",0,"11"]]}';
        // "1O:05.0" is garbled; dropping it would shift runner 2 onto no time.
        devices.raceTimer!.data = '10:00.0,1O:05.0,CR 0 11:00.0';

        await controller.processReceivedData(ctx);

        expect(controller.hasError, isTrue);
        expect(controller.timingChunks, isNull);
      });

      testWidgets('stops with an error when no finish times arrive',
          (tester) async {
        final ctx = await pumpContext(tester);
        when(mockMasterRace.getRaceRunnerByBib('1'))
            .thenAnswer((_) async => _runner(1));
        devices.bibRecorder!.data = '{"teams":["EAGLES"],"r":[["1","R1",0,"11"]]}';
        devices.raceTimer!.data = ' ';

        await controller.processReceivedData(ctx);

        expect(controller.hasError, isTrue);
      });

      testWidgets('keeps a non-numeric unknown bib as text', (tester) async {
        final ctx = await pumpContext(tester);
        when(mockMasterRace.getRaceRunnerByBib('A12'))
            .thenAnswer((_) async => null);
        devices.bibRecorder!.data = '{"teams":[],"r":[["A12","",null,""]]}';
        devices.raceTimer!.data = '10:00.0,CR 0 10:30.0';

        await controller.processReceivedData(ctx);

        expect(controller.raceRunners, ['A12']);
        expect(controller.hasBibConflicts, isTrue);
      });

      testWidgets(
          'an old Timer\'s extra time after a confirmation becomes '
          'resolvable', (tester) async {
        final ctx = await pumpContext(tester);
        for (final bib in ['1', '2']) {
          when(mockMasterRace.getRaceRunnerByBib(bib))
              .thenAnswer((_) async => _runner(int.parse(bib)));
        }
        devices.bibRecorder!.data =
            '{"teams":["EAGLES"],"r":[["1","R1",0,"11"],["2","R2",0,"11"]]}';
        // Three confirmed times, then "extra time" with no times of its own.
        devices.raceTimer!.data =
            '10:00.0,10:05.0,10:10.0,CR 0 10:15.0,ET 1 10:20.0';

        await controller.processReceivedData(ctx);

        expect(controller.hasError, isFalse);
        final chunk = controller.timingChunks!.single;
        expect(chunk.timingData.map((d) => d.time),
            ['10:00.0', '10:05.0', '10:10.0']);
        expect(chunk.conflictRecord!.conflict!.type, ConflictType.extraTime);
        expect(chunk.recordCount, 2);
        expect(controller.hasTimingConflicts, isTrue);
      });

      testWidgets('drops everything from a load that fails part-way',
          (tester) async {
        final ctx = await pumpContext(tester);
        when(mockMasterRace.getRaceRunnerByBib('1'))
            .thenAnswer((_) async => _runner(1));
        devices.bibRecorder!.data =
            '{"teams":["EAGLES"],"r":[["1","R1",0,"11"]]}';
        // Four more finishers than bibs, more than the last chunk can drop.
        devices.raceTimer!.data =
            '10:00.0,10:01.0,10:02.0,CR 0 10:03.0,10:04.0,10:05.0,CR 0 10:06.0';

        await controller.processReceivedData(ctx);

        expect(controller.hasError, isTrue);
        expect(controller.resultsLoaded, isFalse);
        expect(controller.raceRunners, isNull);
        expect(controller.timingChunks, isNull);
        // Nothing half-loaded can be saved.
        expect(await controller.saveCurrentResults(), isNull);
        verifyNever(mockMasterRace.saveResults(any));
      });

      testWidgets('stops with an error when no bibs arrive', (tester) async {
        final ctx = await pumpContext(tester);
        devices.bibRecorder!.data = '{"teams":[],"r":[]}';
        devices.raceTimer!.data = '10:00.0,CR 0 10:30.0';

        await controller.processReceivedData(ctx);

        expect(controller.hasError, isTrue);
        expect(controller.resultsLoaded, isFalse);
      });
    });

    group('initialize', () {
      test('calls scheduler.addPostFrameCallback', () {
        final mockScheduler = MockIPostFrameCallbackScheduler();
        controller = _buildController(mockMasterRace, devices,
            scheduler: mockScheduler);

        controller.initialize();

        verify(mockScheduler.addPostFrameCallback(any)).called(1);
      });
    });

    // -----------------------------------------------------------------------
    group('showBibConflictsSheet', () {
      testWidgets('when raceRunners is null, shows error and returns early',
          (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(builder: (ctx) {
              capturedContext = ctx;
              return const SizedBox();
            }),
          ),
        );

        controller.raceRunners = null;

        await controller.showBibConflictsSheet(capturedContext);
        await tester.pump(const Duration(seconds: 4));

        expect(controller.raceRunners, isNull);
      });

      testWidgets(
          'when raceRunners has no int conflicts, shows error and returns early',
          (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(builder: (ctx) {
              capturedContext = ctx;
              return const SizedBox();
            }),
          ),
        );

        controller.raceRunners = [_runner(1), _runner(2)];

        await controller.showBibConflictsSheet(capturedContext);
        await tester.pump(const Duration(seconds: 4));

        expect(controller.raceRunners!.length, 2);
        expect(controller.raceRunners!.every((r) => r is RaceRunner), isTrue);
      });
    });

    // -----------------------------------------------------------------------
    group('showTimingConflictsSheet', () {
      testWidgets('when timingChunks is null, shows error and returns early',
          (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(builder: (ctx) {
              capturedContext = ctx;
              return const SizedBox();
            }),
          ),
        );

        controller.timingChunks = null;

        await controller.showTimingConflictsSheet(capturedContext);
        await tester.pump(const Duration(seconds: 4));

        expect(controller.timingChunks, isNull);
      });

      testWidgets('when raceRunners is null, shows error and returns early',
          (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(builder: (ctx) {
              capturedContext = ctx;
              return const SizedBox();
            }),
          ),
        );

        controller.timingChunks = [
          TimingChunk(id: 0, timingData: [TimingDatum(time: '10:00.0')]),
        ];
        controller.raceRunners = null;

        await controller.showTimingConflictsSheet(capturedContext);
        await tester.pump(const Duration(seconds: 4));

        expect(controller.raceRunners, isNull);
      });

      testWidgets(
          'when no conflict chunks exist, shows error and returns early',
          (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(builder: (ctx) {
              capturedContext = ctx;
              return const SizedBox();
            }),
          ),
        );

        controller.timingChunks = [
          TimingChunk(id: 0, timingData: [TimingDatum(time: '10:00.0')]),
        ];
        controller.raceRunners = [_runner(1)];

        await controller.showTimingConflictsSheet(capturedContext);
        await tester.pump(const Duration(seconds: 4));

        expect(controller.timingChunks!.any((c) => c.hasConflict), isFalse);
      });
    });

    // -----------------------------------------------------------------------
    group(
        '_ensureBibNumberAndRunnerRecordLengthsAreEqual via processReceivedData',
        () {
      testWidgets(
          'keeps every bib and flags a missing time when bibs outnumber finishers',
          (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(builder: (ctx) {
              capturedContext = ctx;
              return const SizedBox();
            }),
          ),
        );

        final runner1 = _runner(1);
        final runner2 = _runner(2);
        when(mockMasterRace.getRaceRunnerByBib('1'))
            .thenAnswer((_) async => runner1);
        when(mockMasterRace.getRaceRunnerByBib('2'))
            .thenAnswer((_) async => runner2);

        // 2 bib entries, 1 timing record → raceRunners.length(2) > totalTimingRecords(1)
        // Raw JSON bib format is accepted directly by BibDecodeUtils.
        const rawBibJson =
            '{"teams":["EAGLES"],"r":[["1","Runner 1",0,"11"],["2","Runner 2",0,"11"]]}';
        // Raw timing: 1 plain datum + 1 confirmRunner delimiter → 1 chunk with 1 record.
        const rawTiming = '10:00.0,CR 0 10:30.0';

        devices.bibRecorder!.data = rawBibJson;
        devices.raceTimer!.data = rawTiming;

        await controller.processReceivedData(capturedContext);

        // The earliest bib used to be deleted, shifting everyone's time.
        expect(controller.raceRunners?.length, 2);
        final conflict = controller.timingChunks!.last.conflictRecord!.conflict!;
        expect(conflict.type, ConflictType.missingTime);
        expect(conflict.offBy, 1);
        expect(controller.hasTimingConflicts, isTrue);
      });

      testWidgets(
          'flags an extra time when finishers outnumber bibs',
          (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(builder: (ctx) {
              capturedContext = ctx;
              return const SizedBox();
            }),
          ),
        );

        final runner1 = _runner(1);
        when(mockMasterRace.getRaceRunnerByBib('1'))
            .thenAnswer((_) async => runner1);

        // 1 bib entry, 2 timing records → raceRunners.length(1) < totalTimingRecords(2)
        const rawBibJson =
            '{"teams":["EAGLES"],"r":[["1","Runner 1",0,"11"]]}';
        // Raw timing: 2 plain datums + 1 confirmRunner delimiter → 1 chunk with 2 records.
        const rawTiming = '10:00.0,11:00.0,CR 0 11:30.0';

        devices.bibRecorder!.data = rawBibJson;
        devices.raceTimer!.data = rawTiming;

        await controller.processReceivedData(capturedContext);

        // Adding a missing-time conflict here made the mismatch worse.
        expect(controller.timingChunks, hasLength(1));
        final conflict = controller.timingChunks!.last.conflictRecord!.conflict!;
        expect(conflict.type, ConflictType.extraTime);
        expect(conflict.offBy, 1);
        expect(controller.hasTimingConflicts, isTrue);
      });
    });
  });
}
