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

  testWidgets('can split a team into boys\' and girls\' teams',
      (tester) async {
    List<Map<String, dynamic>>? added;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              added = await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const Scaffold(
                  body: ImportedRunnersSelectionSheet(importedRunners: [
                    {'name': 'Ann Lee', 'grade': 10, 'bib': '101',
                      'team': 'Archie Williams', 'gender': 'F'},
                    {'name': 'Bo Park', 'grade': 11, 'bib': '102',
                      'team': 'Archie Williams', 'gender': 'M'},
                  ]),
                ),
              ));
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('split_boys_girls')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Selected'));
    await tester.pumpAndSettle();

    expect(added!.map((r) => r['team']),
        ['Archie Williams - Girls', 'Archie Williams - Boys']);
  });

  testWidgets('offers no split when the rows name no teams', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ImportedRunnersSelectionSheet(importedRunners: [
          {'name': 'Ann Lee', 'grade': 10, 'bib': '101', 'gender': 'F'},
          {'name': 'Bo Park', 'grade': 11, 'bib': '102', 'gender': 'M'},
        ]),
      ),
    ));

    expect(find.byKey(const ValueKey('split_boys_girls')), findsNothing);
  });
}
