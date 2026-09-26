import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/merge_conflicts/models/ui_record.dart';
import 'package:xceleration/coach/merge_conflicts/widgets/runner_time_cells.dart';

// The box a coach types a missing time into. It starts holding "TBD"; typing
// must replace that, not add to it.

void main() {
  Future<TextEditingController> pump(WidgetTester tester,
      {bool autofocus = false}) async {
    final record = UIRecord(
      place: 1,
      initialTime: 'TBD',
      isOriginallyTBD: true,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 140,
          child: MissingTimeCell(
            controller: record.timeController,
            time: record.time,
            onSubmitted: (_) {},
            onChanged: (_) {},
            autofocus: autofocus,
            isOriginallyTBD: true,
            record: record,
          ),
        ),
      ),
    ));
    await tester.pump();
    return record.timeController;
  }

  testWidgets('a box focused after tapping + starts empty', (tester) async {
    final controller = await pump(tester, autofocus: true);

    expect(controller.text, isEmpty);
    await tester.enterText(find.byType(TextField), '15:20.26');
    expect(controller.text, '15:20.26');
  });

  testWidgets('tapping the box clears TBD too', (tester) async {
    final controller = await pump(tester);
    expect(controller.text, 'TBD');

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(controller.text, isEmpty);
  });

  testWidgets('only time characters can be typed', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), '1a5:2x0.2b6');

    expect(find.text('15:20.26'), findsOneWidget);
  });
}
