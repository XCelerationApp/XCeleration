import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/runners_management_screen/services/roster_export.dart';
import 'package:xceleration/core/utils/file_processing.dart';
import 'package:xceleration/core/utils/file_utils.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

// A roster exported from one race, edited in a spreadsheet, and imported
// into the next has to come back exactly as it went out.

RaceRunner _runner(String bib, String name, int grade, String team) =>
    RaceRunner(
      raceId: 1,
      runner: Runner(bibNumber: bib, name: name, grade: grade),
      team: Team(name: team, abbreviation: team, color: const Color(0xFF000000)),
    );

void main() {
  final roster = [
    _runner('102', 'Bo Park', 11, 'Hawks'),
    _runner('10', 'Ann Lee', 10, 'Eagles'),
    _runner('9', 'Lee, Cy', 12, 'Eagles'),
    _runner('007', 'José "JJ" Núñez', 9, 'Redwood High School'),
  ];

  test('lists runners by team, then bib in number order', () {
    final rows = RosterExport.rows(roster);

    expect(rows.first, ['Bib', 'Name', 'Grade', 'Team']);
    expect(rows.skip(1).map((r) => '${r[3]} ${r[0]}'), [
      'Eagles 9',
      'Eagles 10',
      'Hawks 102',
      'Redwood High School 007',
    ]);
  });

  test('imports back exactly as it went out', () {
    final text = RosterExport.csv(roster);

    final result = processSpreadsheetData(FileUtils.parseCsvText(text));

    expect(result.skipped, isEmpty);
    final back = {
      for (final r in result.runners)
        r['bib']: '${r['name']}|${r['grade']}|${r['team']}'
    };
    expect(back, {
      '102': 'Bo Park|11|Hawks',
      '10': 'Ann Lee|10|Eagles',
      '9': 'Lee, Cy|12|Eagles',
      '007': 'José "JJ" Núñez|9|Redwood High School',
    });
  });
}
