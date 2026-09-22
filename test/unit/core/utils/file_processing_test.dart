import 'package:flutter_test/flutter_test.dart';
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

    test('rows without a header that are too short are reported', () {
      final result = processSpreadsheetData([
        ['Ann Lee', '10', '101'],
        ['Bo Park', '11'],
      ]);

      expect(result.runners, hasLength(1));
      expect(result.skipped, ['Row 2: needs a name, grade and bib number']);
    });
  });
}
