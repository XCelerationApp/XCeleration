import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/bib_number_recorder/controller/bib_number_controller.dart';
import 'package:xceleration/assistant/bib_number_recorder/model/bib_datum_record.dart';
import 'package:xceleration/assistant/bib_number_recorder/widgets/bib_input_widget.dart';

import 'bib_input_widget_test.mocks.dart';

// A duplicate bib shows whose bib it is and where else it was entered, so
// the volunteer knows which runner to ask for.

@GenerateMocks([BibNumberController])
void main() {
  late MockBibNumberController controller;

  setUp(() {
    controller = MockBibNumberController();
    when(controller.raceStopped).thenReturn(false);
    when(controller.controllers)
        .thenReturn([TextEditingController(text: '7')]);
    when(controller.focusNodes).thenReturn([FocusNode()]);
  });

  Future<void> pumpRow(WidgetTester tester, BibDatumRecord record) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BibInputWidget(index: 0, record: record, controller: controller),
        ),
      ));

  BibDatumRecord duplicate(List<int> places) => BibDatumRecord(
        bib: '7',
        name: 'John Peter',
        teamAbbreviation: 'TIG',
        grade: '11',
        flags: BibDatumRecordFlags(
          notInDatabase: false,
          duplicateBibNumber: true,
          duplicatePlaces: places,
        ),
      );

  testWidgets('shows the other place and the runner\'s name', (tester) async {
    await pumpRow(tester, duplicate([4]));

    expect(find.text('Duplicate, also place 4'), findsOneWidget);
    expect(find.text('John Peter, TIG'), findsOneWidget);
  });

  testWidgets('lists every other place', (tester) async {
    await pumpRow(tester, duplicate([4, 9]));

    expect(find.text('Duplicate, also places 4, 9'), findsOneWidget);
  });

  testWidgets('an unknown bib still says it was not found', (tester) async {
    await pumpRow(
      tester,
      BibDatumRecord(
        bib: '7',
        name: '',
        teamAbbreviation: '',
        grade: '',
        flags: const BibDatumRecordFlags(
            notInDatabase: true, duplicateBibNumber: false),
      ),
    );

    expect(find.text('Runner not found'), findsOneWidget);
  });
}
