import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/assistant/bib_number_recorder/controller/bib_number_controller.dart';
import 'package:xceleration/assistant/shared/models/bib_record.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/services/assistant_storage_service.dart';
import 'package:xceleration/assistant/shared/services/demo_race_generator_impl.dart';
import 'package:xceleration/assistant/shared/services/received_race_resolver.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';

import 'bib_number_controller_test.mocks.dart';

// The coach sends the Bib Recorder its race and roster, often more than
// once: again after adding runners, or because the first send looked like it
// failed. Once bibs are recorded the volunteer chooses between updating the
// race and keeping a copy; either way no bib is ever lost.

void main() {
  final storage = AssistantStorageService.instance;
  late BibNumberController recorder;

  String race(String name, DateTime date) =>
      RaceRecord(raceId: 3, date: date, name: name, type: 'race').encode();

  final invitational = race('Invitational', DateTime(2026, 9, 12));
  final ava = BibDatum(
    bib: '101',
    name: 'Ava Lee',
    teamAbbreviation: 'NHS',
    grade: '11',
  );
  final mia = BibDatum(
    bib: '102',
    name: 'Mia Chen',
    teamAbbreviation: 'NHS',
    grade: '9',
  );

  Future<String> send(String race, List<BibDatum> roster) async =>
      '$race---${await BibEncodeUtils.getEncodedBibData(roster)}';

  /// What the volunteer was asked, and answers [choice].
  late List<RaceAlreadyHere> asked;
  AskAboutRace answer(ReceivedRaceChoice choice) => (here) async {
    asked.add(here);
    return choice;
  };
  final update = ReceivedRaceChoice.update;
  final keepSeparate = ReceivedRaceChoice.keepSeparate;

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

  Future<List<String>> savedBibs(int raceId) async => [
    for (final r
        in (await storage.getBibRecords(raceId) as Success<List<BibRecord>>)
            .value)
      r.bibNumber,
  ];

  Future<List<RaceRecord>> racesNamed(String name) async =>
      (await storage.getRaces(DeviceName.bibRecorder.toString())
              as Success<List<RaceRecord>>)
          .value
          .where((r) => r.name == name)
          .toList();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(
      Directory.systemTemp.createTempSync('bib_controller_load').path,
    );
  });

  setUp(() async {
    final db = await storage.database;
    for (final table in ['bib_records', 'runners', 'race_history']) {
      await db.delete(table);
    }
    asked = [];
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

  group('the same race sent again', () {
    test('with nothing recorded, opens with the new roster, unasked', () async {
      await recorder.processLoadedRaceData(await send(invitational, [ava]));

      await recorder.processLoadedRaceData(
        await send(invitational, [ava, mia]),
        ask: answer(update),
      );

      expect(asked, isEmpty);
      expect(recorder.runners, hasLength(2));
    });

    test('with bibs recorded, asks, saying how the roster changed', () async {
      await record(['101', '999']);

      await recorder.processLoadedRaceData(
        await send(invitational, [ava, mia]),
        ask: answer(update),
      );

      expect(asked.single.renamed, isFalse);
      expect(asked.single.recorded, 2);
      expect(asked.single.rosterChanges?.added, 1);
    });

    test('updated, keeps its bibs', () async {
      await record(['101', '999']);

      await recorder.processLoadedRaceData(
        await send(invitational, [ava]),
        ask: answer(update),
      );

      expect(recorder.bibRecords.map((r) => r.bib), ['101', '999']);
      expect(await savedBibs(3), ['101', '999']);
    });

    test('updated mid-race, keeps recording', () async {
      await record(['101']);

      await recorder.processLoadedRaceData(
        await send(invitational, [ava]),
        ask: answer(update),
      );

      expect(recorder.raceStopped, isFalse);
      await recorder.addHeardBib('999');
      expect(await savedBibs(3), ['101', '999']);
    });

    test(
      'updated, a runner added since is found for a bib already recorded',
      () async {
        await record(['101', '102']);
        expect(recorder.bibRecords[1].flags.notInDatabase, isTrue);

        await recorder.processLoadedRaceData(
          await send(invitational, [ava, mia]),
          ask: answer(update),
        );

        expect(recorder.bibRecords[1].name, 'Mia Chen');
        expect(recorder.bibRecords[1].flags.notInDatabase, isFalse);
      },
    );

    test(
      'copied, opens an empty copy and the original keeps its bibs',
      () async {
        await record(['101']);

        await recorder.processLoadedRaceData(
          await send(invitational, [ava, mia]),
          ask: answer(keepSeparate),
        );

        expect(recorder.currentRace?.name, 'Invitational (copy)');
        expect(recorder.bibRecords, isEmpty);
        expect(recorder.runners, hasLength(2));
        expect(await savedBibs(3), ['101']);
      },
    );

    test(
      'reopened later, it has one copy of each runner and its bibs',
      () async {
        await record(['101']);
        for (var i = 0; i < 2; i++) {
          await recorder.processLoadedRaceData(
            await send(invitational, [ava, mia]),
            ask: answer(update),
          );
        }

        // As when the app is opened again.
        final reopened = build();
        await opened(reopened);
        addTearDown(reopened.dispose);

        expect(reopened.currentRace?.name, 'Invitational');
        expect(
          reopened.runners.map((r) => r.bib),
          unorderedEquals(['101', '102']),
        );
        expect(reopened.bibRecords.map((r) => r.bib), ['101']);
      },
    );

    test('twice at once, asks once and opens once', () async {
      await record(['101']);
      final data = await send(invitational, [ava]);

      await Future.wait([
        recorder.processLoadedRaceData(data, ask: answer(update)),
        recorder.processLoadedRaceData(data, ask: answer(update)),
      ]);

      expect(asked, hasLength(1));
      expect(recorder.bibRecords.map((r) => r.bib), ['101']);
      expect(recorder.runners, hasLength(1));
      expect(await racesNamed('Invitational'), hasLength(1));
    });
  });

  group('a race under the same number with another name', () {
    final saturday = race('Saturday Invitational', DateTime(2026, 9, 12));

    test('asks whether it is the same race', () async {
      await record(['101']);

      await recorder.processLoadedRaceData(
        await send(saturday, [ava]),
        ask: answer(update),
      );

      expect(asked.single.renamed, isTrue);
      expect(asked.single.existing.name, 'Invitational');
      expect(asked.single.sent.name, 'Saturday Invitational');
    });

    test('the same race, renamed by the coach, keeps its bibs', () async {
      await record(['101']);

      await recorder.processLoadedRaceData(
        await send(saturday, [ava]),
        ask: answer(update),
      );

      expect(recorder.currentRace?.name, 'Saturday Invitational');
      expect(recorder.currentRace?.raceId, 3);
      expect(recorder.bibRecords.map((r) => r.bib), ['101']);
      expect(await racesNamed('Invitational'), isEmpty);
    });

    test(
      'a different race starts empty, and the first keeps its bibs',
      () async {
        await record(['101']);

        await recorder.processLoadedRaceData(
          await send(race('Conference Finals', DateTime(2026, 9, 19)), [mia]),
          ask: answer(keepSeparate),
        );

        expect(recorder.currentRace?.name, 'Conference Finals');
        expect(recorder.bibRecords, isEmpty);
        expect(await savedBibs(3), ['101']);
      },
    );
  });
}
