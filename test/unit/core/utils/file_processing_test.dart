import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/utils/file_utils.dart';
import 'package:xceleration/core/utils/file_processing.dart';

void main() {
  group('processSpreadsheetData', () {
    test('imports valid rows and lists every skipped row with the reason', () {
      final result = processSpreadsheetData([
        ['Name', 'Grade', 'Bib'],
        ['Ann Lee', '10', '101'],
        ['Bo Park', 'K', '102'], // grade not 9–12
        ['', '11', '103'], // no name
        ['Cy Diaz', '12', 'abc'], // bib not a number
        ['Di Fox', 'Sr', '104'],
      ]);

      expect(result.runners.map((r) => r['name']), ['Ann Lee', 'Di Fox']);
      expect(result.skipped, [
        'Row 3 (Bo Park): grade is not 9–12',
        'Row 4: no name',
        'Row 5 (Cy Diaz): bib is not a number',
      ]);
    });

    test('blank rows are ignored, not reported', () {
      final result = processSpreadsheetData([
        ['Name', 'Grade', 'Bib'],
        ['', '', ''],
        ['Ann Lee', '9', '7'],
      ]);

      expect(result.runners, hasLength(1));
      expect(result.skipped, isEmpty);
    });

    test('rows with a bib handed out but no runner yet are not reported', () {
      // A league roster had bibs 1033–1199 listed ahead, names to come.
      final result = processSpreadsheetData([
        ['Bib', 'Name', 'Grade'],
        ['1032', 'Ann Lee', '10'],
        ['1033', '', ''],
        ['1034', '', ''],
        ['1122', 'Mathias Gomez', ''], // a runner, missing a grade
      ]);

      expect(result.runners.map((r) => r['name']), ['Ann Lee']);
      expect(result.skipped, ['Row 5 (Mathias Gomez): grade is not 9–12']);
    });

    test('keeps a bib\'s leading zeros, as typed bibs do', () {
      // A runner typed in by hand keeps "007", so an imported one must too,
      // or the Bib Recorder's "007" matches only one of them.
      final result = processSpreadsheetData([
        ['Name', 'Grade', 'Bib'],
        ['Ann Lee', '10', '007'],
        ['Bo Park', '11', '0120'],
      ]);

      expect(result.runners.map((r) => r['bib']), ['007', '0120']);
    });

    test('reads a bib stored as a number the way it is printed', () {
      // Spreadsheet number cells arrive as 12 or 12.0.
      final result = processSpreadsheetData([
        ['Name', 'Grade', 'Bib'],
        ['Ann Lee', '10', 12],
        ['Bo Park', '11', 13.0],
        ['Cy Diaz', '12', '14.0'],
      ]);

      expect(result.runners.map((r) => r['bib']), ['12', '13', '14']);
    });

    test('rows without a header that are too short are reported', () {
      final result = processSpreadsheetData([
        ['Ann Lee', '10', '101'],
        ['Bo Park', '11'],
      ]);

      expect(result.runners, hasLength(1));
      expect(result.skipped, ['Row 2: needs a name, grade and bib number']);
    });

    group('headings', () {
      test('reads a Team or School column', () {
        for (final heading in ['Team', 'School', 'Team Name']) {
          final result = processSpreadsheetData([
            ['Bib', 'Name', 'Grade', heading],
            ['101', 'Ann Lee', '10', 'Eagles'],
          ]);
          expect(result.runners.single['team'], 'Eagles', reason: heading);
        }
      });

      test('leaves team out when the column is blank', () {
        final result = processSpreadsheetData([
          ['Bib', 'Name', 'Grade', 'Team'],
          ['101', 'Ann Lee', '10', ''],
        ]);
        expect(result.runners.single.containsKey('team'), isFalse);
      });

      test('reads the common ways of writing the bib, name and grade', () {
        final sheets = [
          ['Bib #', 'Athlete', 'Yr'],
          ['Athlete #', 'Name', 'Grade'],
          ['Runner #', 'Full Name', 'Class'],
          ['Bib No.', 'Runner Name', 'Grade Level'],
          ['#', 'Name', 'Year'],
        ];
        for (final header in sheets) {
          final result = processSpreadsheetData([
            header,
            ['101', 'Ann Lee', '10'],
          ]);
          expect(result.runners.single, {'name': 'Ann Lee', 'grade': 10,
              'bib': '101'}, reason: header.join(', '));
        }
      });

      test('builds the name from First and Last columns in any order', () {
        final result = processSpreadsheetData([
          ['Last', 'First', 'Bib', 'Grade', 'M/F'],
          ['Lee', 'Ann', '101', 'Jr', 'F'],
        ]);
        expect(result.runners.single,
            {'name': 'Ann Lee', 'grade': 11, 'bib': '101', 'gender': 'F'});
      });
    });

    test('reads the sample spreadsheet the app offers', () {
      // The app shows this sheet as the example to copy, so it must import.
      final text =
          File('assets/sample_sheets/sample_spreadsheet.csv').readAsStringSync();
      final result = processSpreadsheetData(FileUtils.parseCsvText(text));

      expect(result.skipped, isEmpty);
      expect(result.runners.map((r) => '${r['bib']} ${r['name']} ${r['team']}'),
          ['1001 Alex Smith Eagles', '1002 Jamie Rivera Eagles',
           '2001 Sam Lee Hawks']);
    });
  });
}
