import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/runners_management_screen/widgets/imported_runners_selection_sheet.dart';

void main() {
  Widget build(List<String> skipped) => MaterialApp(
        home: Scaffold(
          body: ImportedRunnersSelectionSheet(
            importedRunners: const [
              {'name': 'Ann Lee', 'grade': 10, 'bib': '101'},
            ],
            skippedRows: skipped,
          ),
        ),
      );

  testWidgets('says how many rows were skipped and why', (tester) async {
    await tester.pumpWidget(build(const [
      'Row 3 (Bo Park): grade is not 9–12',
      'Row 4: no name',
    ]));

    expect(find.text('2 rows were not imported'), findsOneWidget);

    await tester.tap(find.text('2 rows were not imported'));
    await tester.pumpAndSettle();

    expect(find.text('Row 3 (Bo Park): grade is not 9–12'), findsOneWidget);
  });

  testWidgets('shows nothing extra when every row was imported',
      (tester) async {
    await tester.pumpWidget(build(const []));

    expect(find.textContaining('not imported'), findsNothing);
    expect(find.text('Ann Lee'), findsOneWidget);
  });

  testWidgets('says which team each runner is going on', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ImportedRunnersSelectionSheet(importedRunners: [
          {'name': 'Ann Lee', 'grade': 10, 'bib': '101', 'team': 'Eagles'},
        ]),
      ),
    ));

    expect(find.text('Grade 10  •  Bib 101  •  Eagles'), findsOneWidget);
  });
}
