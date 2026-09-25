import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/widgets/adjust_times.dart';
import 'package:xceleration/core/app_error.dart';

// The coach can move every time for a Timer who started late or early, see
// that they have, and take it back.

void main() {
  late List<Duration> moves;
  AppError? Function(Duration) onShift({AppError? refuse}) => (by) {
        if (refuse != null) return refuse;
        moves.add(by);
        return null;
      };

  setUp(() => moves = []);

  Future<void> show(WidgetTester tester,
      {Duration shift = Duration.zero, AppError? refuse}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdjustTimesTile(shift: shift, onShift: onShift(refuse: refuse)),
      ),
    ));
  }

  Future<void> enter(WidgetTester tester, String seconds) async {
    await tester.tap(find.text('Adjust Times'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), seconds);
  }

  testWidgets('a late start moves every time later', (tester) async {
    await show(tester);
    await enter(tester, '5');

    await tester.tap(find.text('Move All Times'));
    await tester.pumpAndSettle();

    expect(moves, [const Duration(seconds: 5)]);
    expect(find.text('Move All Times'), findsNothing, reason: 'sheet closes');
  });

  testWidgets('an early start moves them earlier', (tester) async {
    await show(tester);
    await enter(tester, '2.5');

    await tester.tap(find.text('Started early'));
    await tester.tap(find.text('Move All Times'));
    await tester.pumpAndSettle();

    expect(moves, [const Duration(milliseconds: -2500)]);
  });

  testWidgets('asks again for a number it cannot use', (tester) async {
    await show(tester);
    await enter(tester, '');

    await tester.tap(find.text('Move All Times'));
    await tester.pumpAndSettle();

    expect(moves, isEmpty);
    expect(find.textContaining('Enter how many seconds'), findsOneWidget);
  });

  testWidgets('says why a move was refused', (tester) async {
    await show(tester,
        refuse: const AppError(userMessage: 'That would put 4.50 below zero.'));
    await enter(tester, '9');

    await tester.tap(find.text('Move All Times'));
    await tester.pumpAndSettle();

    expect(find.text('That would put 4.50 below zero.'), findsOneWidget);
  });

  testWidgets('once moved, says so and can take it back', (tester) async {
    await show(tester, shift: const Duration(seconds: 5));

    expect(find.text('All times moved 5.0 seconds later.'), findsOneWidget);
    await tester.tap(find.text('Undo'));

    expect(moves, [const Duration(seconds: -5)]);
  });
}
