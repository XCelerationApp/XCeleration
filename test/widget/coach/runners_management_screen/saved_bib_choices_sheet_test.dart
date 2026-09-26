import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/runners_management_screen/services/roster_importer.dart';
import 'package:xceleration/coach/runners_management_screen/widgets/saved_bib_choices_sheet.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import 'package:xceleration/shared/models/database/runner.dart';

// Bibs in an import that were already saved with other details: one list,
// keep or replace them all at once, or pick one by one.

RunnerDetailsConflict _conflict(String bib, String saved, String sheet) =>
    RunnerDetailsConflict(
      existing: Runner(runnerId: int.parse(bib), name: saved, bibNumber: bib, grade: 12),
      name: sheet,
      grade: 10,
    );

void main() {
  final conflicts = [
    _conflict('1010', 'Devon Eagles', 'Catalina Karr'),
    _conflict('1011', 'Sam Lee', 'Jo Park'),
    _conflict('1012', 'Ria Moss', 'Ria Moss-Hart'),
  ];

  late Object? popped;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    popped = 'not popped';
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async => popped = await sheet(
                context: context,
                title: '3 Bibs Are Already Saved',
                body: SavedBibChoicesSheet(conflicts: conflicts),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> done(WidgetTester tester) async {
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every bib at once, keeping saved details by default',
      (tester) async {
    await open(tester);

    expect(find.text('Devon Eagles'), findsOneWidget);
    expect(find.text('Catalina Karr'), findsOneWidget);
    expect(find.text('Bib 1012'), findsOneWidget);

    await done(tester);
    expect(popped, isEmpty);
  });

  testWidgets('uses the spreadsheet for all of them', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('use_all_spreadsheet')));
    await tester.pump();
    await done(tester);

    expect(popped, conflicts);
  });

  testWidgets('or just the ones picked', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('use_all_spreadsheet')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('saved_1011')));
    await tester.pump();
    await done(tester);

    expect(popped, [conflicts[0], conflicts[2]]);
  });
}
