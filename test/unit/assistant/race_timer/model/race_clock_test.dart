import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/race_timer/model/timing_data.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/core/result.dart';

import 'timing_data_test.mocks.dart';

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
    wall = start;
    mono = const Duration(hours: 5);
    timing = TimingData(
        storage: storage, now: () => wall, monotonic: () => mono);
    timing.currentRace = RaceRecord(
        raceId: 1, date: start, name: 'Clock', type: 'timer', stopped: true);
    timing.startTime = start;
    timing.raceStopped = false;
  });

  tearDown(() => timing.dispose());

  void advance(Duration d, {Duration wallJump = Duration.zero}) {
    mono += d;
    wall = wall.add(d + wallJump);
  }

  test('counts from the start', () {
    advance(const Duration(minutes: 1));
    expect(timing.raceElapsed, const Duration(minutes: 1));
  });

  test('a phone clock change mid-race does not move times backwards', () {
    advance(const Duration(minutes: 16));
    final before = timing.raceElapsed;

    // The phone's clock jumps back 5 seconds (e.g. an automatic time sync).
    advance(const Duration(milliseconds: 300),
        wallJump: const Duration(seconds: -5));
    final after = timing.raceElapsed;

    expect(after, before + const Duration(milliseconds: 300));
  });

  test('reopening the race re-reads the phone clock', () {
    advance(const Duration(minutes: 2));
    expect(timing.raceElapsed, const Duration(minutes: 2));

    // After a restart the monotonic clock starts over; the start time is
    // all that survives.
    mono = Duration.zero;
    wall = wall.add(const Duration(minutes: 3));
    timing.currentRace = RaceRecord(
        raceId: 1, date: start, name: 'Clock', type: 'timer', stopped: false);

    expect(timing.raceElapsed, const Duration(minutes: 5));
  });

  test('a stopped race shows its final time', () {
    advance(const Duration(minutes: 20));
    timing.raceDuration = timing.raceElapsed;
    timing.raceStopped = true;
    advance(const Duration(minutes: 5));

    expect(timing.raceElapsed, const Duration(minutes: 20));
  });
}
