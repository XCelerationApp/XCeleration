import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/races_screen/controller/races_controller.dart';
import 'package:xceleration/coach/races_screen/widgets/races_list.dart';
import 'package:xceleration/shared/models/database/race.dart';

// The races list shows only the sections that have races in them, and one
// message when there are none at all.

class _FakeRaces extends ChangeNotifier implements RacesController {
  _FakeRaces(this.races);

  @override
  final List<Race> races;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> pump(WidgetTester tester, List<Race> races) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [RacesList(controller: _FakeRaces(races), canEdit: true)],
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('leaves out a section with no races', (tester) async {
    await pump(tester, [
      Race(raceId: 1, raceName: 'County Meet', flowState: Race.FLOW_FINISHED),
    ]);

    expect(find.text('Finished'), findsOneWidget);
    expect(find.text('Upcoming'), findsNothing);
    expect(find.text('In Progress'), findsNothing);
    expect(find.text('No upcoming races'), findsNothing);
  });

  testWidgets('says how to start when there are no races', (tester) async {
    await pump(tester, []);

    expect(find.text('No races yet'), findsOneWidget);
    expect(find.text('Tap + to set up your first race'), findsOneWidget);
  });
}
