import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xceleration/core/utils/file_processing.dart';
import 'package:xceleration/core/utils/file_utils.dart';
import 'package:xceleration/core/utils/google_sheets_service.dart';
import 'package:xceleration/core/utils/sheet_tabs.dart';
import 'package:csv/csv.dart';

// A roster spreadsheet may keep each school on its own tab. Importing all
// tabs must bring every runner in, each school as a team.

void main() {
  group('combineTabs', () {
    test('uses each tab\'s name as the team of its runners', () {
      final combined = combineTabs({
        'Tamalpais': [
          ['Bib', 'Name', 'Grade'],
          ['101', 'Ann Lee', '10'],
        ],
        'Drake': [
          ['Bib #', 'First', 'Last', 'Yr'],
          ['007', 'Bo', 'Park', 'Sr'],
        ],
      });

      expect(combined.rows, [
        ['Bib', 'Name', 'Grade', 'Gender', 'Team'],
        ['101', 'Ann Lee', '10', '', 'Tamalpais'],
        ['007', 'Bo Park', '12', '', 'Drake'],
      ]);
      expect(combined.skipped, isEmpty);
    });

    test('keeps a runner\'s own team over the tab\'s name', () {
      final combined = combineTabs({
        'Varsity': [
          ['Bib', 'Name', 'Grade', 'Team'],
          ['101', 'Ann Lee', '10', 'Tamalpais'],
          ['102', 'Cy Diaz', '11', ''],
        ],
      });

      expect(combined.rows.skip(1).map((r) => r[4]), ['Tamalpais', 'Varsity']);
    });

    test('says which tab a left-out row came from', () {
      final combined = combineTabs({
        'Drake': [
          ['Bib', 'Name', 'Grade'],
          ['103', 'Kid Tooyoung', '8'],
        ],
      });

      expect(combined.skipped,
          ['Drake, row 2 (Kid Tooyoung): grade is not 9–12']);
    });

    test('reads back through the import unchanged', () {
      final combined = combineTabs({
        'Tamalpais': [
          ['Bib', 'Name', 'Grade', 'M/F'],
          ['007', 'José "JJ" Núñez', '9', 'M'],
          ['102', 'Lee, Cy', '11', 'F'],
        ],
      });
      final csv = const ListToCsvConverter().convert(combined.rows);

      final back = processSpreadsheetData(FileUtils.parseCsvText(csv));

      expect(back.skipped, isEmpty);
      expect(back.runners, [
        {'name': 'José "JJ" Núñez', 'grade': 9, 'bib': '007', 'gender': 'M',
            'team': 'Tamalpais'},
        {'name': 'Lee, Cy', 'grade': 11, 'bib': '102', 'gender': 'F',
            'team': 'Tamalpais'},
      ]);
    });
  });

  group('reading tabs from Google', () {
    late List<http.Request> requests;

    GoogleSheetsService service(
            http.Response Function(http.Request) respond) =>
        GoogleSheetsService(
          httpClient: MockClient((request) async {
            requests.add(request);
            return respond(request);
          }),
        );

    setUp(() => requests = []);

    test('lists the visible tabs in order', () async {
      final sheets = service((_) => http.Response(
          jsonEncode({
            'sheets': [
              {'properties': {'title': 'Tamalpais'}},
              {'properties': {'title': 'Old roster', 'hidden': true}},
              {'properties': {'title': 'Drake'}},
            ]
          }),
          200));

      final tabs = await sheets.sheetTabs('file1', 'token');

      expect(tabs, ['Tamalpais', 'Drake']);
      expect(requests.single.headers['Authorization'], 'Bearer token');
    });

    test('gives null when the tabs cannot be read', () async {
      final sheets = service((_) => http.Response('denied', 403));

      expect(await sheets.sheetTabs('file1', 'token'), isNull);
    });

    test('reads a tab\'s cells as shown, quoting its name', () async {
      final sheets = service((_) => http.Response.bytes(
          utf8.encode(jsonEncode({
            'values': [
              ['Bib', 'Name', 'Grade'],
              ['007', 'José Núñez', '9'],
            ]
          })),
          200));

      final rows = await sheets.tabRows('file1', "St. Mary's", 'token');

      expect(rows, [
        ['Bib', 'Name', 'Grade'],
        ['007', 'José Núñez', '9'],
      ]);
      expect(Uri.decodeFull(requests.single.url.path),
          "/v4/spreadsheets/file1/values/'St. Mary''s'");
      expect(requests.single.url.queryParameters['valueRenderOption'],
          'FORMATTED_VALUE');
    });
  });
}
