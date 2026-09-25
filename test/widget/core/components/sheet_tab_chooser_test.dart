import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/components/sheet_tab_chooser.dart';

void main() {
  Future<List<String>?> choose(WidgetTester tester, String tap) async {
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
    await tester.tap(find.text(tap));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    return chosen;
  }

  testWidgets('All tabs picks every tab', (tester) async {
    expect(await choose(tester, 'All tabs'), ['Tamalpais', 'Drake', 'Redwood']);
  });

  testWidgets('a tab picks just that one', (tester) async {
    expect(await choose(tester, 'Drake'), ['Drake']);
  });
}
