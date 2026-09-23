import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/resolve_bib_number_screen/model/bib_conflict.dart';
import 'package:xceleration/coach/resolve_bib_number_screen/widgets/duplicate_bib_card.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

// Choosing which finish a repeated bib belongs to.

const _eagles = Team(teamId: 1, name: 'Eagles', abbreviation: 'EAG');

final _alice = RaceRunner(
  raceId: 1,
  runner:
      Runner(runnerId: 1, name: 'Alice Green', bibNumber: '412', grade: 11),
  team: _eagles,
);

DuplicateBibConflict _conflict({
  List<ConflictOccurrence>? occurrences,
}) =>
    DuplicateBibConflict(
      bibNumber: '412',
      runner: _alice,
      occurrences: occurrences ??
          const [
            ConflictOccurrence(place: 8, time: '16:43.00'),
            ConflictOccurrence(place: 12, time: '17:20.00'),
          ],
    );

Future<void> _pump(WidgetTester tester, DuplicateBibConflict conflict,
    {ValueChanged<int>? onChosen}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: DuplicateBibCard(
          conflict: conflict,
          onFinishChosen: onChosen ?? (_) {},
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offers every finish the bib was recorded at', (tester) async {
    await _pump(tester, _conflict());

    // Including the earliest: the screen used to treat that one as correct
    // and only ask about the later finish.
    expect(find.text('8th place'), findsOneWidget);
    expect(find.text('12th place'), findsOneWidget);
    expect(find.text('16:43.00'), findsOneWidget);
    expect(find.text('17:20.00'), findsOneWidget);
  });

  testWidgets('names the runner the bib belongs to', (tester) async {
    await _pump(tester, _conflict());

    expect(find.text('Alice Green'), findsOneWidget);
    expect(find.text('Eagles · Grade 11'), findsOneWidget);
    expect(find.text('#412'), findsOneWidget);
  });

  testWidgets('reports the finish that was tapped', (tester) async {
    int? chosen;
    await _pump(tester, _conflict(), onChosen: (place) => chosen = place);

    await tester.tap(find.text('12th place'));
    await tester.pumpAndSettle();

    expect(chosen, 12);
  });

  testWidgets('handles a bib recorded three times', (tester) async {
    await _pump(
      tester,
      _conflict(occurrences: const [
        ConflictOccurrence(place: 3, time: '15:10.00'),
        ConflictOccurrence(place: 8, time: '16:43.00'),
        ConflictOccurrence(place: 12, time: '17:20.00'),
      ]),
    );

    expect(find.text('3rd place'), findsOneWidget);
    expect(find.text('8th place'), findsOneWidget);
    expect(find.text('12th place'), findsOneWidget);
    expect(find.textContaining('other 2 each need'), findsOneWidget);
  });

  testWidgets('says when a finish has no settled time', (tester) async {
    await _pump(
      tester,
      _conflict(occurrences: const [
        ConflictOccurrence(place: 8, time: '16:43.00'),
        ConflictOccurrence(place: 12),
      ]),
    );

    expect(find.text('Time not settled'), findsOneWidget,
        reason: 'better than a time that may belong to someone else');
  });

  testWidgets('shows who each finish sits between', (tester) async {
    await _pump(
      tester,
      _conflict(occurrences: const [
        ConflictOccurrence(place: 8, time: '16:43.00', nearby: [
          NearbyFinisher(
              place: 7, name: 'Bo Nguyen', team: 'Hawks', bibNumber: '301'),
          NearbyFinisher(
              place: 9, name: 'Cy Diaz', team: 'Owls', bibNumber: '302'),
        ]),
        ConflictOccurrence(place: 12, time: '17:20.00'),
      ]),
    );

    // Without this the two finishes are just two times, with nothing to
    // tell them apart.
    expect(find.text('7. Bo Nguyen'), findsOneWidget);
    expect(find.text('9. Cy Diaz'), findsOneWidget);
  });

  testWidgets('fits on a phone', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(
      tester,
      _conflict(occurrences: const [
        ConflictOccurrence(place: 8, time: '16:43.00', nearby: [
          NearbyFinisher(
              place: 7, name: 'Bo Nguyen', team: 'Hawks', bibNumber: '301'),
        ]),
        ConflictOccurrence(place: 12, time: '17:20.00', nearby: [
          NearbyFinisher(
              place: 11, name: 'Di Rossi', team: 'Owls', bibNumber: '303'),
        ]),
      ]),
    );

    expect(find.text('8th place'), findsOneWidget);
    expect(find.text('12th place'), findsOneWidget);
  });
}
