import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/race_timer/model/ui_record.dart';
import 'package:xceleration/assistant/race_timer/widgets/record_list_item.dart';
import 'package:xceleration/core/utils/enums.dart';

// The Timer's red rows say why they are red.

void main() {
  Future<void> pump(WidgetTester tester, UIRecord record) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(body: RecordListItem(uiRecord: record, index: 0)),
      ));

  testWidgets('an extra tap says so, with its time struck out',
      (tester) async {
    await pump(
        tester,
        UIRecord(
            time: '15:42.10',
            textColor: Colors.red,
            type: RecordType.extraTime));

    expect(find.text('Extra tap'), findsOneWidget);
    final time = tester.widget<Text>(find.text('15:42.10'));
    expect(time.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('a missed runner says so instead of TBD', (tester) async {
    await pump(
        tester,
        UIRecord(
            time: 'TBD',
            place: 12,
            textColor: Colors.red,
            type: RecordType.missingTime));

    expect(find.text('Missed runner'), findsOneWidget);
    expect(find.text('TBD'), findsNothing);
    expect(find.text('12'), findsOneWidget);
  });
}
