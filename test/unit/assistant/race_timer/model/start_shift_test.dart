import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/race_timer/model/timing_data.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/time_formatter.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

import 'timing_data_test.mocks.dart';

// A Timer who pressed Start a few seconds after the gun (or before it) says
// so, and the clock and every time already logged move by that much, so the
// coach gets times from the gun.

void main() {
  late MockIAssistantStorageService storage;
  late DateTime wall;
  late Duration mono;
  late TimingData timing;
  final start = DateTime(2026, 9, 21, 10);

  setUpAll(() => provideDummy<Result<void>>(const Success(null)));

  setUp(() {
    storage = MockIAssistantStorageService();
    when(storage.updateRaceStartTime(any, any, any))
        .thenAnswer((_) async => const Success(null));
    when(storage.updateRaceStatus(any, any, any))
        .thenAnswer((_) async => const Success(null));
    when(storage.updateRaceDuration(any, any, any))
        .thenAnswer((_) async => const Success(null));
    when(storage.saveChunk(any, any))
        .thenAnswer((_) async => const Success(null));
    wall = start;
    mono = const Duration(hours: 5);
    timing = TimingData(
        storage: storage, now: () => wall, monotonic: () => mono);
    timing.currentRace = RaceRecord(
        raceId: 1, date: start, name: 'Shift', type: 'timer', stopped: true);
    timing.startTime = start;
    timing.raceStopped = false;
  });

  tearDown(() => timing.dispose());

  void advance(Duration d) {
    mono += d;
    wall = wall.add(d);
  }

  String t(int minutes, [int seconds = 0]) => TimeFormatter.formatDuration(
      Duration(minutes: minutes, seconds: seconds));

  void logFinish() => timing
      .addRunnerTimeRecord(TimingDatum(time: TimeFormatter.formatDuration(
          timing.raceElapsed)));

  List<String> times() => [
        for (final r in timing.uiRecords) r.time,
      ];

  test('started late: the clock and every time move later', () async {
    advance(const Duration(minutes: 16));
    logFinish();
    timing.addConfirmRecord(TimingDatum(
        time: t(16, 5), conflict: Conflict(type: ConflictType.confirmRunner)));
    advance(const Duration(seconds: 30));
    logFinish();

    expect(timing.shiftAllTimes(const Duration(seconds: 3)), isNull);

    expect(times(), [t(16, 3), t(16, 8), t(16, 33)]);
    expect(timing.raceElapsed, const Duration(minutes: 16, seconds: 33));
    expect(timing.timeShift, const Duration(seconds: 3));

    // Times logged afterwards count from the gun too.
    advance(const Duration(seconds: 10));
    logFinish();
    expect(times().last, t(16, 43));

    // And the moved times are saved.
    await timing.pendingWrites;
    verify(storage.saveChunk(1, any)).called(greaterThanOrEqualTo(2));
  });

  test('started early: every time moves earlier', () {
    advance(const Duration(minutes: 16));
    logFinish();

    expect(timing.shiftAllTimes(const Duration(seconds: -2)), isNull);

    expect(times(), [t(15, 58)]);
    expect(timing.raceElapsed, const Duration(minutes: 15, seconds: 58));
  });

  test('a stopped race keeps its final time moved too', () {
    advance(const Duration(minutes: 20));
    timing.raceDuration = timing.raceElapsed;
    timing.raceStopped = true;

    timing.shiftAllTimes(const Duration(seconds: 4));

    expect(timing.raceDuration, const Duration(minutes: 20, seconds: 4));
    expect(timing.raceElapsed, const Duration(minutes: 20, seconds: 4));
  });

  test('refused if it would take the clock below zero', () {
    advance(const Duration(seconds: 2));

    expect(timing.shiftAllTimes(const Duration(seconds: -5)), isNotNull);
    expect(timing.raceElapsed, const Duration(seconds: 2));
    expect(timing.timeShift, Duration.zero);
  });

  test('refused before the race starts', () {
    timing.clearRecords();

    expect(timing.shiftAllTimes(const Duration(seconds: 3)), isNotNull);
  });
}
