import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/bib_number_recorder/model/bib_datum_record.dart';
import 'package:xceleration/assistant/race_timer/model/ui_record.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/services/assistant_export_service.dart';
import 'package:xceleration/core/utils/enums.dart';

// An assistant's export is the fallback when a phone cannot reach the coach,
// so its places have to be the finish order exactly.

BibDatumRecord _bib(String bib, {String name = ''}) =>
    BibDatumRecord(bib: bib, name: name, teamAbbreviation: 'EAG', grade: '10');

void main() {
  test('numbers the bibs in finish order', () {
    final rows = AssistantExportService.bibRows(
        [_bib('101', name: 'Alice'), _bib('102', name: 'Bob')]);

    expect(rows, [
      ['1', '101', 'Alice', 'EAG', '10'],
      ['2', '102', 'Bob', 'EAG', '10'],
    ]);
  });

  test('a row left blank takes no place', () {
    final rows =
        AssistantExportService.bibRows([_bib('101'), _bib(''), _bib('103')]);

    expect([for (final r in rows) '${r[0]} ${r[1]}'], ['1 101', '2 103']);
  });

  final race = RaceRecord(
    raceId: 1,
    date: DateTime(2026, 9, 29),
    name: 'State Meet',
    type: DeviceName.raceTimer.toString(),
  );

  UIRecord time(String t, int? place, RecordType type) => UIRecord(
      time: t, place: place, textColor: Colors.black, type: type);

  test('the Timer table has only finish times, under a heading row', () {
    final table = AssistantExportService.timerTable([
      time('15:01.20', 1, RecordType.runnerTime),
      time('15:09.00', null, RecordType.confirmRunner),
      time('15:12.84', 2, RecordType.runnerTime),
    ]);

    expect(table, [
      ['Place', 'Time'],
      ['1', '15:01.20'],
      ['2', '15:12.84'],
    ]);
  });

  test('the Bib Recorder table heads its rows', () {
    final table =
        AssistantExportService.bibTable([_bib('101', name: 'Alice')]);

    expect(table.first, ['Place', 'Bib', 'Name', 'Team', 'Grade']);
    expect(table.last, ['1', '101', 'Alice', 'EAG', '10']);
  });

  test('as text, the race and date head tab-separated columns', () {
    final text = AssistantExportService.asText(race, [
      ['Place', 'Time'],
      ['1', '15:01.20'],
    ]);

    expect(text, 'State Meet — 9/29/2026\n\nPlace\tTime\n1\t15:01.20');
  });

  test('a Google Sheet is named for the race, the list and the date', () {
    expect(AssistantExportService.sheetTitle(race, 'Bib Numbers'),
        'State Meet — Bib Numbers (9/29/2026)');
  });
}
