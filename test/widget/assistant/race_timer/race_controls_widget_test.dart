import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/race_timer/controller/timing_controller.dart';
import 'package:xceleration/assistant/race_timer/widgets/race_controls_widget.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';

import '../../../unit/assistant/race_timer/controller/timing_controller_test.mocks.dart';

// The bottom of the Timer holds the one button that matters at each moment:
// Start before the gun, Log Finish while the clock runs, then Resume and
// Share Times once it is stopped.

void main() {
  late TimingController timing;
  var elapsed = Duration.zero;

  setUpAll(() {
    provideDummy<Result<void>>(const Success(null));
    provideDummy<Result<List<RaceRecord>>>(const Success([]));
    provideDummy<Result<List<TimingChunk>>>(const Success([]));
  });

  setUp(() {
    final storage = MockIAssistantStorageService();
    when(storage.getRaces(any)).thenAnswer((_) async => const Success([]));
    when(storage.updateRaceStatus(any, any, any))
        .thenAnswer((_) async => const Success(null));
    when(storage.updateRaceStartTime(any, any, any))
        .thenAnswer((_) async => const Success(null));
    when(storage.updateRaceDuration(any, any, any))
        .thenAnswer((_) async => const Success(null));
    when(storage.saveChunk(any, any))
        .thenAnswer((_) async => const Success(null));
    final haptics = MockIHapticFeedback();
    when(haptics.vibrate()).thenAnswer((_) async {});
    when(haptics.lightImpact()).thenAnswer((_) async {});

    elapsed = Duration.zero;
    final start = DateTime(2026, 9, 26, 9);
    timing = TimingController(
      storage: storage,
      hapticFeedback: haptics,
      now: () => start.add(elapsed),
      monotonic: () => elapsed,
    );
    timing.currentRace = RaceRecord(
      raceId: 1,
      date: DateTime(2026, 9, 26),
      name: 'Invitational',
      type: DeviceName.raceTimer.toString(),
      stopped: true,
    );
  });

  tearDown(() => timing.dispose());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: timing,
            builder: (_, _) => RaceControlsWidget(controller: timing),
          ),
        ),
      ));

  testWidgets('offers Start Race before the gun', (tester) async {
    await pump(tester);

    expect(find.text('Start Race'), findsOneWidget);
    expect(find.text('Log Finish'), findsNothing);
  });

  testWidgets('starts the clock as the finger lands on Start Race',
      (tester) async {
    await pump(tester);

    final gesture = await tester
        .startGesture(tester.getCenter(find.text('Start Race')));
    await tester.pump();
    // Still pressed: the race has already started.
    expect(timing.startTime, isNotNull);
    await gesture.up();
  });

  testWidgets('logs a finish as the finger lands, before it lifts',
      (tester) async {
    timing.startRace();
    await pump(tester);
    expect(find.text('Runner 1'), findsOneWidget);

    elapsed = const Duration(minutes: 16, seconds: 2);
    final gesture = await tester
        .startGesture(tester.getCenter(find.text('Log Finish')));
    await tester.pump();
    expect(timing.runnerCount, 1);
    // A finger lifting a moment later does not change the time taken.
    elapsed = const Duration(minutes: 16, seconds: 3);
    await gesture.up();
    await tester.pump();

    expect(timing.runnerCount, 1);
    expect(find.text('Runner 2'), findsOneWidget);
  });

  testWidgets('shows the count checks once a finish is logged',
      (tester) async {
    timing.startRace();
    await pump(tester);
    expect(find.text('Counts match'), findsNothing);

    timing.logTime();
    await tester.pump();

    expect(find.text('Counts match'), findsOneWidget);
    expect(find.text('Counts differ?'), findsOneWidget);
  });

  testWidgets('offers Resume and Share Times once stopped', (tester) async {
    timing.startRace();
    timing.logTime();
    timing.stopRace();
    await pump(tester);

    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Share Times'), findsOneWidget);
    expect(find.text('Log Finish'), findsNothing);
  });

  testWidgets('fits a small phone at a large text size', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    timing.startRace();
    timing.logTime();

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: RaceControlsWidget(controller: timing),
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
  });
}
