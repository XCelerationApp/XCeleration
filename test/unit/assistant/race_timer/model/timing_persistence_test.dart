import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/assistant/race_timer/model/timing_data.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/services/assistant_storage_service.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

// What the Timer saves must be exactly what it shows, even when taps come
// faster than the database, so the race survives a crash. These tests use a
// real (in-memory) database and read the race back as a restart would.

void main() {
  final storage = AssistantStorageService.instance;
  final race = RaceRecord(
    raceId: 7,
    date: DateTime(2026, 9, 21),
    name: 'Crash Test',
    type: DeviceName.raceTimer.toString(),
  );
  late TimingData timing;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await storage.database;
    await db.delete('timing_chunks');
    await db.delete('race_history');
    await storage.saveNewRace(race);
    await storage.saveChunk(race.raceId, TimingChunk(id: 0, timingData: []));
    timing = TimingData(storage: storage);
    timing.currentRace = race;
  });

  tearDown(() => timing.dispose());

  String t(int s) => '0:${s.toString().padLeft(2, '0')}.00';

  Future<List<TimingChunk>> reload() async {
    await timing.pendingWrites;
    final result = await storage.getChunks(race.raceId);
    return (result as Success<List<TimingChunk>>).value;
  }

  List<String> times(List<TimingChunk> chunks) =>
      chunks.expand((c) => c.timingData.map((d) => d.time)).toList();

  test('a burst of taps is saved in full and in order', () async {
    // No awaits between taps: a pack finishing together.
    for (var i = 1; i <= 20; i++) {
      timing.addRunnerTimeRecord(TimingDatum(time: t(i)));
    }

    expect(times(await reload()), [for (var i = 1; i <= 20; i++) t(i)]);
  });

  test('taps across confirmations and conflicts come back exactly', () async {
    timing.addRunnerTimeRecord(TimingDatum(time: t(1)));
    timing.addRunnerTimeRecord(TimingDatum(time: t(2)));
    timing.addConfirmRecord(TimingDatum(
        time: t(3), conflict: Conflict(type: ConflictType.confirmRunner)));
    timing.addRunnerTimeRecord(TimingDatum(time: t(4)));
    timing.addRunnerTimeRecord(TimingDatum(time: t(5)));
    timing.addExtraTimeRecord(TimingDatum(
        time: t(6), conflict: Conflict(type: ConflictType.extraTime)));
    timing.addRunnerTimeRecord(TimingDatum(time: t(7)));
    timing.addMissingTimeRecord(TimingDatum(
        time: t(8), conflict: Conflict(type: ConflictType.missingTime)));
    timing.addMissingTimeRecord(TimingDatum(
        time: t(9), conflict: Conflict(type: ConflictType.missingTime)));

    final chunks = await reload();
    expect(chunks.map((c) => c.encode()), [
      '${t(1)},${t(2)} CR 1 ${t(3)}',
      '${t(4)},${t(5)} ET 1 ${t(6)}',
      '${t(7)} MT 2 ${t(9)}',
    ]);
  });

  test('times logged after clearing the race are saved', () async {
    timing.addRunnerTimeRecord(TimingDatum(time: t(1)));
    timing.addConfirmRecord(TimingDatum(
        time: t(2), conflict: Conflict(type: ConflictType.confirmRunner)));
    timing.addRunnerTimeRecord(TimingDatum(time: t(3)));
    // What "Clear race times" does.
    timing.clearRecords();
    await timing.enqueueWrite(
        () => storage.deleteChunks(race.raceId), 'clear');

    timing.addRunnerTimeRecord(TimingDatum(time: t(10)));
    timing.addRunnerTimeRecord(TimingDatum(time: t(11)));

    expect(times(await reload()), [t(10), t(11)]);
  });

  test('clearing waits for saves still queued, so no times come back',
      () async {
    for (var i = 1; i <= 5; i++) {
      timing.addRunnerTimeRecord(TimingDatum(time: t(i)));
    }
    timing.clearRecords();
    await timing.enqueueWrite(
        () => storage.deleteChunks(race.raceId), 'clear');

    expect(await reload(), isEmpty);
  });
}
