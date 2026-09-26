import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/components/sheet_tab_chooser.dart';

// A spreadsheet with a tab per school (or per school's boys and girls): the
// coach ticks the ones racing.

void main() {
  Future<List<String>?> choose(WidgetTester tester, List<String> taps) async {
    List<String>? chosen;
    var done = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              chosen = await chooseSheetTabs(
                  context, 'Roster', ['Tamalpais', 'Drake', 'Redwood']);
              done = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    for (final tap in taps) {
      await tester.tap(find.text(tap));
      await tester.pumpAndSettle();
    }
    expect(done, isTrue);
    return chosen;
  }

  testWidgets('Select all picks every tab', (tester) async {
    expect(await choose(tester, ['Select all', 'Import 3 tabs']),
        ['Tamalpais', 'Drake', 'Redwood']);
  });

  testWidgets('any tabs can be ticked, and come back in sheet order',
      (tester) async {
    expect(await choose(tester, ['Redwood', 'Tamalpais', 'Import 2 tabs']),
        ['Tamalpais', 'Redwood']);
  });

  testWidgets('a tab ticked twice is unticked', (tester) async {
    expect(await choose(tester, ['Drake', 'Redwood', 'Drake', 'Import 1 tab']),
        ['Redwood']);
  });

  testWidgets('nothing is imported until a tab is ticked', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SheetTabChooser(fileName: 'Roster', tabs: ['Drake']),
      ),
    ));

    await tester.tap(find.text('Tick the tabs to import'));
    await tester.pumpAndSettle();

    // Still here: nothing to import.
    expect(find.byType(SheetTabChooser), findsOneWidget);
  });
}
