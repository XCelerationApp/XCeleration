import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/assistant/bib_number_recorder/controller/bib_number_data_controller.dart';
import 'package:xceleration/assistant/bib_number_recorder/model/bib_datum_record.dart';
import 'package:xceleration/assistant/shared/models/bib_record.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/services/assistant_storage_service.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/text_input_factory.dart';

// The Bib Recorder's list is the finish order: position N is whoever crossed
// Nth. What is saved has to be that list exactly, with no gaps and nothing
// left behind, because a restart reads it back and the coach receives it.

void main() {
  final storage = AssistantStorageService.instance;
  final race = RaceRecord(
    raceId: 11,
    date: DateTime(2026, 9, 12),
    name: 'Invitational',
    type: 'bibRecorder',
  );
  late BibNumberDataController bibs;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(
        Directory.systemTemp.createTempSync('bib_data_controller').path);
  });

  setUp(() async {
    final db = await storage.database;
    await db.delete('bib_records');
    await db.delete('race_history');
    bibs = BibNumberDataController(
        storage: storage, textInputFactory: const TextInputFactory());
    bibs.setCurrentRace(race);
  });

  tearDown(() => bibs.dispose());

  BibDatumRecord bib(String number) => BibDatumRecord(
      bib: number, name: '', teamAbbreviation: '', grade: '');

  Future<List<String>> saved() async {
    final records =
        (await storage.getBibRecords(race.raceId) as Success<List<BibRecord>>)
            .value;
    records.sort((a, b) => a.bibId.compareTo(b.bibId));
    return [for (final r in records) r.bibNumber];
  }

  test('removing a bib from the middle closes the gap in what is saved',
      () async {
    for (final n in ['101', '102', '103', '104']) {
      await bibs.addBibRecord(bib(n));
    }

    await bibs.removeBibRecord(1);

    expect(await saved(), ['101', '103', '104']);
    expect(bibs.bibRecords.map((r) => r.bib), ['101', '103', '104']);
  });

  test('a row not filled in yet takes no place in the finish order', () async {
    await bibs.addBibRecord(bib('101'));
    await bibs.addBibRecord(bib(''));
    await bibs.addBibRecord(bib('103'));

    await bibs.removeBibRecord(0);

    expect(await saved(), ['103']);
  });

  test('removing every row leaves nothing saved', () async {
    await bibs.addBibRecord(bib('101'));
    await bibs.addBibRecord(bib('102'));

    await bibs.removeBibRecord(1);
    await bibs.removeBibRecord(0);

    expect(await saved(), isEmpty);
  });

  test('clearing out blank rows keeps the rest in order', () async {
    for (final n in ['', '101', '', '102', '']) {
      await bibs.addBibRecord(bib(n));
    }

    await bibs.cleanEmptyRecords();

    expect(bibs.bibRecords.map((r) => r.bib), ['101', '102']);
    expect(await saved(), ['101', '102']);
  });

  test('saving to the database writes the list as shown', () async {
    for (final n in ['101', '', '102']) {
      await bibs.addBibRecord(bib(n));
    }

    await bibs.saveBibRecordsToDatabase(race.raceId);

    expect(await saved(), ['101', '102']);
  });

  test('clearing the race\'s bibs clears what is saved too', () async {
    // Otherwise they come back the next time the app opens.
    await bibs.addBibRecord(bib('101'));
    await bibs.addBibRecord(bib('102'));
    await bibs.saveBibRecordsToDatabase(race.raceId);

    await bibs.clearRecordedBibs();

    expect(bibs.bibRecords, isEmpty);
    expect(await saved(), isEmpty);
  });

  test('finds each bib entered more than once', () async {
    for (final n in ['101', '102', '101', '103', '102', '101']) {
      await bibs.addBibRecord(bib(n));
    }

    expect(bibs.checkDuplicateRecords(), ['101', '102', '101']);
  });

  test('blank rows are not duplicates of each other', () async {
    await bibs.addBibRecord(bib(''));
    await bibs.addBibRecord(bib(''));

    expect(bibs.checkDuplicateRecords(), isEmpty);
    expect(bibs.countEmptyBibNumbers(), 2);
    expect(bibs.hasNonEmptyBibNumbers(), isFalse);
  });

  test('an out-of-range index is ignored', () async {
    await bibs.addBibRecord(bib('101'));

    await bibs.removeBibRecord(5);
    bibs.updateBibRecord(-1, bib('999'));

    expect(bibs.bibRecords.map((r) => r.bib), ['101']);
  });

  test('editing a bib updates its text field', () async {
    await bibs.addBibRecord(bib('101'));

    bibs.updateBibRecord(0, bib('110'));

    expect(bibs.controllers.single.text, '110');
  });

  test('nothing is saved while no race is open', () async {
    bibs.setCurrentRace(null);
    await bibs.addBibRecord(bib('101'));
    await bibs.addBibRecord(bib('102'));

    await bibs.removeBibRecord(0);

    expect(await saved(), isEmpty);
  });
}
