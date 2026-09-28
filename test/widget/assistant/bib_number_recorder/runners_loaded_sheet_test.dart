import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/bib_number_recorder/widgets/runners_loaded_sheet.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';

// The Bib Recorder's runner list can be searched and filtered by team, to
// find who a bib belongs to without scrolling a whole meet's roster.

void main() {
  final runners = [
    BibDatum(bib: '101', name: 'Ava Lee', teamAbbreviation: 'NHS', grade: '11'),
    BibDatum(bib: '102', name: 'Mia Chen', teamAbbreviation: 'RHS', grade: '9'),
    BibDatum(bib: '215', name: 'Zoe Park', teamAbbreviation: 'NHS', grade: '12'),
  ];

  Future<void> pumpSheet(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        home: Scaffold(body: RunnersLoadedSheet(runners: runners)),
      ));

  testWidgets('shows every runner at first', (tester) async {
    await pumpSheet(tester);

    expect(find.text('3 runners'), findsOneWidget);
    for (final name in ['Ava Lee', 'Mia Chen', 'Zoe Park']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('lists runners by bib number, 2 before 10', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RunnersLoadedSheet(runners: [
          BibDatum(bib: '10', name: 'Ten', teamAbbreviation: 'NHS', grade: '9'),
          BibDatum(bib: '2', name: 'Two', teamAbbreviation: 'NHS', grade: '9'),
        ]),
      ),
    ));

    expect(tester.getTopLeft(find.text('Two')).dy,
        lessThan(tester.getTopLeft(find.text('Ten')).dy));
  });

  testWidgets('searches by name', (tester) async {
    await pumpSheet(tester);

    await tester.enterText(find.byType(TextField), 'mia');
    await tester.pump();

    expect(find.text('Mia Chen'), findsOneWidget);
    expect(find.text('Ava Lee'), findsNothing);
    expect(find.text('1 of 3 runners'), findsOneWidget);
  });

  testWidgets('searches by the start of a bib', (tester) async {
    await pumpSheet(tester);

    await tester.enterText(find.byType(TextField), '10');
    await tester.pump();

    expect(find.text('Ava Lee'), findsOneWidget);
    expect(find.text('Mia Chen'), findsOneWidget);
    expect(find.text('Zoe Park'), findsNothing);
  });

  testWidgets('filters by team', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.byKey(const ValueKey('team_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team_filter_NHS')));
    await tester.pumpAndSettle();

    expect(find.text('Ava Lee'), findsOneWidget);
    expect(find.text('Zoe Park'), findsOneWidget);
    expect(find.text('Mia Chen'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('team_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team_filter_all')));
    await tester.pumpAndSettle();

    expect(find.text('3 runners'), findsOneWidget);
  });

  testWidgets('says when nothing matches', (tester) async {
    await pumpSheet(tester);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pump();

    expect(find.text('No runners match'), findsOneWidget);
  });
}
