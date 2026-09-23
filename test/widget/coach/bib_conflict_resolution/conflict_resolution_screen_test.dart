import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/bib_conflict_resolution/screen/conflict_resolution_screen.dart';

// Getting out of the bib conflict prototype. It is reached from a debug-only
// button, so the only way back is the one the screen draws itself.

void main() {
  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ConflictResolutionScreen(),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('back on the first conflict returns to the summary',
      (tester) async {
    await openScreen(tester);
    await tester.tap(find.text('Start Resolving'));
    await tester.pumpAndSettle();
    expect(find.text('Start Resolving'), findsNothing);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Start Resolving'), findsOneWidget,
        reason: 'the first conflict is not a dead end');
  });

  testWidgets('back on the summary leaves the screen', (tester) async {
    await openScreen(tester);
    expect(find.text('open'), findsNothing);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget,
        reason: 'the summary is the way out of the prototype');
  });
}
