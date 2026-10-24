import 'dart:io';

import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/race_from_coach.dart';
import 'package:xceleration/assistant/shared/models/bib_record.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/services/assistant_storage_service.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/controller/load_results_controller.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/database/race.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';

import 'load_results_controller_test.mocks.dart';

// A coach who records the bibs on their own phone: the race is handed to
// this phone's Bib Recorder, and the bibs it records come back to Load
// Results without sending anything, since a phone cannot send to itself.

void main() {
  final storage = AssistantStorageService.instance;
  late MockMasterRace masterRace;
  late DevicesManager devices;
  late LoadResultsController controller;

  final sent = RaceRecord(
          raceId: 5, date: DateTime(2026, 9, 12), name: 'Invitational',
          type: 'race')
      .encode();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(
        Directory.systemTemp.createTempSync('bibs_on_this_phone').path);
  });

  setUp(() async {
    final db = await storage.database;
    for (final table in ['bib_records', 'runners', 'race_history']) {
      await db.delete(table);
    }
    masterRace = MockMasterRace();
    when(masterRace.raceId).thenReturn(5);
    when(masterRace.race)
        .thenAnswer((_) async => Race(raceId: 5, raceName: 'Invitational'));
    devices = DeviceConnectionService.createDevices(
        DeviceName.coach, DeviceType.browserDevice);
    controller = LoadResultsController(
      masterRace: masterRace,
      devices: devices,
      assistantStorage: storage,
    );
  });

  /// Hands the race over as the Send screen does, and records [bibs].
  Future<void> recordOnThisPhone(List<String> bibs) async {
    final roster = await BibEncodeUtils.getEncodedBibData([
      BibDatum(bib: '101', name: 'Ava', teamAbbreviation: 'NHS', grade: '11'),
    ]);
    final stored = (await storeRaceFromCoach(storage, '$sent---$roster')
            as Success<StoredRaceFromCoach>)
        .value;
    await storage.saveBibRecords(stored.race.raceId, [
      for (final (i, bib) in bibs.indexed)
        BibRecord(
            raceId: stored.race.raceId,
            bibId: i,
            bibNumber: bib,
            createdAt: DateTime(2026, 9, 12)),
    ]);
  }

  test('offers nothing when this phone recorded no bibs', () async {
    expect(await controller.bibsFromThisPhone(), isNull);
  });

  test('brings back the bibs recorded here, in finish order', () async {
    await recordOnThisPhone(['101', '999', '101']);

    final encoded = await controller.bibsFromThisPhone();
    final bibs = (await BibDecodeUtils.decodeEncodedRunners(encoded!)
            as Success<List<BibDatum>>)
        .value;

    expect(bibs.map((b) => b.bib), ['101', '999', '101']);
  });

  test('ignores another race\'s bibs', () async {
    await recordOnThisPhone(['101']);
    when(masterRace.race)
        .thenAnswer((_) async => Race(raceId: 5, raceName: 'Conference'));

    expect(await controller.bibsFromThisPhone(), isNull);
  });

  test('fills the Bib Recorder\'s place and waits for the Timer', () async {
    await recordOnThisPhone(['101']);
    final encoded = (await controller.bibsFromThisPhone())!;

    await controller.useBibsFromThisPhone(_NoContext(), encoded);

    expect(devices.bibRecorder!.isFinished, isTrue);
    expect(devices.bibRecorder!.data, encoded);
    expect(controller.resultsLoaded, isFalse,
        reason: 'the Timer has not sent its times yet');
  });
}

class _NoContext extends Fake implements BuildContext {}
