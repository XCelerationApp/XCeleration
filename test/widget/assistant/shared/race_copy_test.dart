import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/services/assistant_export_service.dart';
import 'package:xceleration/assistant/shared/services/race_copy.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/i_google_sheets_service.dart';

// "Download a Copy" in the Timer and Bib Recorder menus: the race copied as
// text, or made into a Google Sheet, for when a phone cannot reach the coach.

class _FakeSheets implements IGoogleSheetsService {
  bool signedIn = true;
  String? createdTitle;
  List<List<dynamic>>? written;

  @override
  Future<bool> signIn() async => signedIn;

  @override
  Future<String?> createSheet({required String title}) async {
    createdTitle = title;
    return 'sheet-1';
  }

  @override
  Future<bool> updateSheet({
    required String spreadsheetId,
    required List<List<dynamic>> data,
  }) async {
    written = data;
    return true;
  }

  @override
  Future<Uri> getSheetUri(String spreadsheetId) async =>
      Uri.parse('https://docs.google.com/spreadsheets/d/$spreadsheetId');
}

final _race = RaceRecord(
  raceId: 1,
  date: DateTime(2026, 9, 29),
  name: 'State Meet',
  type: DeviceName.bibRecorder.toString(),
);

const _table = [
  ['Place', 'Bib'],
  ['1', '101'],
];

void main() {
  late _FakeSheets sheets;
  late List<DownloadFormat> filesAsked;
  String? clipboard;

  setUp(() {
    sheets = _FakeSheets();
    filesAsked = [];
    clipboard = null;
  });

  Future<void> open(WidgetTester tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => saveRaceCopy(
              context,
              race: _race,
              what: 'Bib Numbers',
              table: _table,
              sheets: sheets,
              exportFile: (format) async {
                filesAsked.add(format);
                return Success(XFile('/tmp/none'));
              },
            ),
            child: const Text('Download'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
  }

  // Lets the "Copied" or error toast run out.
  Future<void> settleToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('offers text and Google Sheets beside the files',
      (tester) async {
    await open(tester);

    expect(find.text('Copy as Text'), findsOneWidget);
    expect(find.text('Google Sheets'), findsOneWidget);
    expect(find.text('CSV File'), findsOneWidget);
    expect(find.text('PDF File'), findsOneWidget);
  });

  testWidgets('copies the race as text and says so', (tester) async {
    await open(tester);

    await tester.tap(find.text('Copy as Text'));
    await tester.pumpAndSettle();

    expect(clipboard, AssistantExportService.asText(_race, _table));
    expect(find.text('Copied'), findsOneWidget);
    expect(filesAsked, isEmpty, reason: 'no file is made for text');
    await settleToast(tester);
  });

  testWidgets('makes a Google Sheet of the list, named for the race',
      (tester) async {
    await open(tester);

    await tester.tap(find.text('Google Sheets'));
    await tester.pumpAndSettle();

    expect(sheets.createdTitle, 'State Meet — Bib Numbers (9/29/2026)');
    expect(sheets.written, _table);
    // Then how to open or share it.
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('says so when Google sign-in does not go through',
      (tester) async {
    sheets.signedIn = false;
    await open(tester);

    await tester.tap(find.text('Google Sheets'));
    await tester.pumpAndSettle();

    expect(sheets.createdTitle, isNull);
    expect(find.textContaining('Could not make a Google Sheet'),
        findsOneWidget);
    await settleToast(tester);
  });
}
