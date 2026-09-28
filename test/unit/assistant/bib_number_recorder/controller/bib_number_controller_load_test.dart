import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/assistant/bib_number_recorder/controller/bib_number_controller.dart';
import 'package:xceleration/assistant/shared/models/bib_record.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/services/assistant_storage_service.dart';
import 'package:xceleration/assistant/shared/services/demo_race_generator_impl.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';

import 'bib_number_controller_test.mocks.dart';

// The coach sends the Bib Recorder its race and roster, often more than
// once: again after adding runners, or because the first send looked like it
// failed. Sending it again must never lose the bibs already recorded.

void main() {
  final storage = AssistantStorageService.instance;
  late BibNumberController recorder;

  String race(String name, DateTime date) =>
      RaceRecord(raceId: 3, date: date, name: name, type: 'race').encode();

  final invitational = race('Invitational', DateTime(2026, 9, 12));
  final ava = BibDatum(
      bib: '101', name: 'Ava Lee', teamAbbreviation: 'NHS', grade: '11');
  final mia = BibDatum(
      bib: '102', name: 'Mia Chen', teamAbbreviation: 'NHS', grade: '9');

  Future<String> send(String race, List<BibDatum> roster) async =>
      '$race---${await BibEncodeUtils.getEncodedBibData(roster)}';

  BibNumberController build() => BibNumberController(
        storage: storage,
        tutorialManager: MockTutorialManager(),
        demoRaceGenerator: DemoRaceGeneratorImpl(),
        deviceConnectionFactory: MockIDeviceConnectionFactory(),
        scheduler: MockIPostFrameScheduler(),
      );

  Future<void> opened(BibNumberController c) async {
    while (c.loadingRace) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<List<String>> savedBibs(int raceId) async =>
      [for (final r in (await storage.getBibRecords(raceId)
              as Success<List<BibRecord>>)
          .value)
        r.bibNumber];

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(
        Directory.systemTemp.createTempSync('bib_controller_load').path);
  });

  setUp(() async {
    final db = await storage.database;
    for (final table in ['bib_records', 'runners', 'race_history']) {
      await db.delete(table);
    }
    recorder = build();
    await opened(recorder);
  });

  tearDown(() => recorder.dispose());

  /// Opens the Invitational and records [bibs] as runners finish.
  Future<void> record(List<String> bibs) async {
    await recorder.processLoadedRaceData(await send(invitational, [ava]));
    recorder.raceStopped = false;
    for (final bib in bibs) {
      await recorder.addHeardBib(bib);
    }
  }

  test('the same race sent again keeps its bibs', () async {
    await record(['101', '999']);

    await recorder.processLoadedRaceData(await send(invitational, [ava]));

    expect(recorder.bibRecords.map((r) => r.bib), ['101', '999']);
    expect(await savedBibs(3), ['101', '999']);
  });

  test('sent again mid-race, it keeps recording', () async {
    await record(['101']);

    await recorder.processLoadedRaceData(await send(invitational, [ava]));

    expect(recorder.raceStopped, isFalse);
    await recorder.addHeardBib('999');
    expect(await savedBibs(3), ['101', '999']);
  });

  test('a runner added since is found for a bib already recorded', () async {
    await record(['101', '102']);
    expect(recorder.bibRecords[1].flags.notInDatabase, isTrue);

    await recorder.processLoadedRaceData(await send(invitational, [ava, mia]));

    expect(recorder.bibRecords[1].name, 'Mia Chen');
    expect(recorder.bibRecords[1].flags.notInDatabase, isFalse);
  });

  test('reopened later, it has one copy of each runner and its bibs',
      () async {
    await record(['101']);
    await recorder.processLoadedRaceData(await send(invitational, [ava, mia]));
    await recorder.processLoadedRaceData(await send(invitational, [ava, mia]));

    // As when the app is opened again.
    final reopened = build();
    await opened(reopened);
    addTearDown(reopened.dispose);

    expect(reopened.currentRace?.name, 'Invitational');
    expect(reopened.runners.map((r) => r.bib), unorderedEquals(['101', '102']));
    expect(reopened.bibRecords.map((r) => r.bib), ['101']);
  });

  test('sent twice at once, it opens once with its bibs', () async {
    await record(['101']);
    final data = await send(invitational, [ava]);

    await Future.wait([
      recorder.processLoadedRaceData(data),
      recorder.processLoadedRaceData(data),
    ]);

    expect(recorder.bibRecords.map((r) => r.bib), ['101']);
    expect(recorder.runners, hasLength(1));
    final races = (await storage.getRaces(DeviceName.bibRecorder.toString())
            as Success<List<RaceRecord>>)
        .value
        .where((r) => r.name == 'Invitational');
    expect(races, hasLength(1));
  });

  test('another race with the same number starts empty, and the first keeps '
      'its bibs', () async {
    await record(['101']);

    await recorder.processLoadedRaceData(
        await send(race('Conference Finals', DateTime(2026, 9, 19)), [mia]));

    expect(recorder.currentRace?.name, 'Conference Finals');
    expect(recorder.bibRecords, isEmpty);
    expect(await savedBibs(3), ['101']);
  });
}
