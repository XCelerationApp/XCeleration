import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/share_race/controller/share_race_controller.dart';
import 'package:xceleration/shared/services/race_results_service.dart';

import '../../../unit/coach/share_race/controller/share_race_controller_test.mocks.dart';

// Exporting results to Google Sheets. A sheet that was not created used to
// pass as a cancel: nothing happened and nothing was said.

void main() {
  const data = RaceResultsData(
    resultsTitle: 'Saturday Invitational',
    individualResults: [],
    overallTeamResults: [],
    headToHeadTeamResults: [],
  );

  testWidgets('a sheet that was not created says so', (tester) async {
    final sheets = MockIGoogleSheetsService();
    when(sheets.signIn()).thenAnswer((_) async => true);
    when(sheets.createSheet(title: anyNamed('title')))
        .thenAnswer((_) async => null);
    final controller = ShareResultsController(
      raceResultsData: data,
      googleSheetsService: sheets,
      formattedResultsController:
          FormattedResultsController(raceResultsData: data),
      shareService: MockIShareService(),
    );
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      context = c;
      return const Scaffold();
    })));

    final done = controller.handleGoogleSheet(context);
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(() => done);
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not create the Google Sheet'),
        findsOneWidget);
    verifyNever(sheets.updateSheet(
        spreadsheetId: anyNamed('spreadsheetId'), data: anyNamed('data')));
    // Let the message's own timer run out.
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
  });
}
