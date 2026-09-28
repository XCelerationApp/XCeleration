import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/assistant/race_timer/controller/timing_controller.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/services/assistant_storage_service.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/haptic_feedback_service.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

// The coach sends the Timer its race. Sending it again, or sending another
// coach's race that happens to share its number, must never touch the times
// already recorded.

class _NoHaptics implements IHapticFeedback {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  final storage = AssistantStorageService.instance;
  late TimingController timer;

  String encoded(String name, DateTime date) => RaceRecord(
        raceId: 3,
        date: date,
        name: name,
        type: 'race',
      ).encode();

  final invitational = encoded('Invitational', DateTime(2026, 9, 12));

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(
        Directory.systemTemp.createTempSync('timing_controller_load').path);
  });

  setUp(() async {
    final db = await storage.database;
    await db.delete('timing_chunks');
    await db.delete('race_history');
    timer = TimingController(storage: storage, hapticFeedback: _NoHaptics());
    await timer.initialLoad;
    await timer.pendingWrites;
  });

  tearDown(() => timer.dispose());

  Future<List<String>> savedTimes(int raceId) async {
    await timer.pendingWrites;
    final chunks =
        (await storage.getChunks(raceId) as Success<List<TimingChunk>>).value;
    return [for (final c in chunks) ...c.timingData.map((d) => d.time)];
  }

  test('opens a race the coach sent', () async {
    await timer.loadRaceFromCoach(invitational);

    expect(timer.currentRace?.name, 'Invitational');
  });

  // The coach's QR code is the Bib Recorder's: the race, '---', the roster.
  // Read whole it failed to parse, and the Timer never got the race.
  test('opens a race from the coach\'s QR code, which carries the roster too',
      () async {
    final roster = await BibEncodeUtils.getEncodedBibData([
      BibDatum(bib: '101', name: 'Ava Lee', teamAbbreviation: 'NHS', grade: '11'),
      BibDatum(bib: '102', name: 'Mia Chen', teamAbbreviation: 'NHS', grade: '9'),
    ]);

    await timer.loadRaceFromCoach('$invitational---$roster');

    expect(timer.currentRace?.name, 'Invitational');
  });

  // A race that cannot be read used to be dropped without a word, and the
  // sheet dinged and closed as if it had worked.
  test('a race that cannot be read is refused', () async {
    expect(await timer.loadRaceFromCoach('not a race'), isFalse);
    expect(await timer.loadRaceFromCoach(invitational), isTrue);
  });

  // Deleting the open race opens the next one straight away: another race
  // on the phone, or the practice race, never an empty screen.
  test('deleting the open race opens the practice race', () async {
    await timer.loadRaceFromCoach(invitational);

    await timer.deleteCurrentRace();

    expect(timer.currentRace?.name, 'Demo Race');
    expect(timer.loadingRace, isFalse);
  });

  test('deleting the practice race, with nothing else, makes it again',
      () async {
    expect(timer.currentRace?.name, 'Demo Race');

    await timer.deleteCurrentRace();

    expect(timer.currentRace?.name, 'Demo Race');
  });

  test('the same race sent again keeps its times', () async {
    await timer.loadRaceFromCoach(invitational);
    timer.addRunnerTimeRecord(TimingDatum(time: '5:01.00'));
    timer.addRunnerTimeRecord(TimingDatum(time: '5:02.00'));
    await timer.pendingWrites;

    await timer.loadRaceFromCoach(invitational);

    expect(await savedTimes(3), ['5:01.00', '5:02.00']);
    expect(timer.uiRecords, hasLength(2),
        reason: 'the reopened race shows what was recorded');
  });

  // Sent again while the race is running, straight after finishes are
  // logged: the clock keeps going and no finish is lost.
  test('the same race sent again mid-race keeps the clock and times',
      () async {
    await timer.loadRaceFromCoach(invitational);
    timer.startRace();
    final started = timer.startTime;
    timer.logTime();
    timer.logTime();

    await timer.loadRaceFromCoach(invitational);

    expect(timer.raceStopped, isFalse);
    expect(timer.startTime?.millisecondsSinceEpoch,
        started?.millisecondsSinceEpoch);
    expect(timer.uiRecords, hasLength(2));
    expect(await savedTimes(3), hasLength(2));
  });

  test('another race with the same number starts empty, and the first keeps '
      'its times', () async {
    await timer.loadRaceFromCoach(invitational);
    timer.addRunnerTimeRecord(TimingDatum(time: '5:01.00'));
    await timer.pendingWrites;

    await timer.loadRaceFromCoach(
        encoded('Conference Finals', DateTime(2026, 9, 19)));

    expect(timer.currentRace?.name, 'Conference Finals');
    expect(timer.uiRecords, isEmpty);
    expect(await savedTimes(3), ['5:01.00']);
  });

  test('clearing the times resets the clock, even after reopening', () async {
    await timer.loadRaceFromCoach(invitational);
    timer.startRace();
    timer.logTime();
    timer.stopRace();
    await timer.pendingWrites;

    await timer.doClearRaceTimes();
    // Reopened, as when the app is restarted.
    await timer.loadRaceFromCoach(invitational);

    expect(timer.startTime, isNull,
        reason: 'the Timer offers Start Race, not Resume of the old clock');
    expect(timer.raceDuration, isNull);
    expect(await savedTimes(3), isEmpty);
  });
}
