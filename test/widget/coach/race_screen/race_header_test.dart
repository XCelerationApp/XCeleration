import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/race_screen/controller/race_form_state.dart';
import 'package:xceleration/coach/race_screen/controller/race_screen_controller.dart';
import 'package:xceleration/coach/race_screen/widgets/race_header.dart';
import 'package:xceleration/shared/models/database/race.dart';

import 'race_header_test.mocks.dart';

// A coach clearing out old test races found a finished race could be neither
// renamed nor deleted from its page: both are offered to its owner at any
// stage now.

@GenerateMocks([RaceScreenController])
void main() {
  late MockRaceScreenController controller;

  Future<void> pump(WidgetTester tester,
      {required String flowState, bool owner = true}) async {
    controller = MockRaceScreenController();
    when(controller.race).thenReturn(Race(
        raceId: 1, raceName: 'Old Test Race', flowState: flowState));
    when(controller.form).thenReturn(RaceFormState());
    when(controller.canEdit).thenReturn(false);
    when(controller.canEditResults).thenReturn(owner);
    when(controller.deleteRace(any)).thenAnswer((_) async {});
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RaceHeader(controller: controller)),
    ));
  }

  testWidgets('a finished race can be renamed', (tester) async {
    await pump(tester, flowState: Race.FLOW_FINISHED);

    expect(find.byKey(const ValueKey('edit_race_name')), findsOneWidget);
  });

  testWidgets('a finished race can be deleted', (tester) async {
    await pump(tester, flowState: Race.FLOW_FINISHED);

    await tester.tap(find.byKey(const ValueKey('race_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Race'));
    await tester.pumpAndSettle();

    verify(controller.deleteRace(any)).called(1);
  });

  testWidgets('someone who does not own the race can do neither',
      (tester) async {
    await pump(tester, flowState: Race.FLOW_FINISHED, owner: false);

    expect(find.byKey(const ValueKey('edit_race_name')), findsNothing);
    expect(find.byKey(const ValueKey('race_menu')), findsNothing);
  });
}
