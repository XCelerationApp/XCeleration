import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/bib_number_recorder/model/bib_datum_record.dart';
import 'package:xceleration/assistant/shared/services/assistant_export_service.dart';

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
}
