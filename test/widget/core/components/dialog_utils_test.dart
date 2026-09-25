import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/components/dialog_utils.dart';

// A dialog's choices are buttons a thumb can hit, and the setup check says
// what is done as well as what is left.

void main() {
  Future<BuildContext> host(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        context = c;
        return const Scaffold();
      }),
    ));
    return context;
  }

  testWidgets('a confirmation returns the choice made', (tester) async {
    final context = await host(tester);
    bool? answer;
    DialogUtils.showConfirmationDialog(context,
            title: 'Stop Recording?',
            content: 'Stop once every runner has finished.',
            confirmText: 'Stop',
            cancelText: 'Keep Recording',
            destructive: true)
        .then((v) => answer = v);
    await tester.pumpAndSettle();

    expect(find.text('Stop Recording?'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  testWidgets('tapping outside a confirmation means no', (tester) async {
    final context = await host(tester);
    bool? answer;
    DialogUtils.showConfirmationDialog(context, title: 'Clear?', content: '')
        .then((v) => answer = v);
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
  });

  testWidgets('the setup check ticks off what is done', (tester) async {
    final context = await host(tester);
    DialogUtils.showChecklistDialog(context,
        title: 'A Few Things Left',
        message: 'Finish these first.',
        items: {'Location': true, 'Race date': false});
    await tester.pumpAndSettle();

    final done = find.ancestor(
        of: find.text('Location'), matching: find.byType(Row));
    final left = find.ancestor(
        of: find.text('Race date'), matching: find.byType(Row));
    expect(
        find.descendant(
            of: done, matching: find.byIcon(Icons.check_circle_rounded)),
        findsOneWidget);
    expect(
        find.descendant(
            of: left, matching: find.byIcon(Icons.radio_button_unchecked)),
        findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('A Few Things Left'), findsNothing);
  });
}
