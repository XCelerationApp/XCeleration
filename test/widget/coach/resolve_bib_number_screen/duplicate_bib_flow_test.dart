import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/resolve_bib_number_screen/model/bib_conflict.dart';
import 'package:xceleration/coach/resolve_bib_number_screen/widgets/duplicate_bib_flow.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

// Working through a repeated bib: which finish is the runner's, then who each
// of the others was.

const _eagles = Team(teamId: 1, name: 'Eagles', abbreviation: 'EAG');

final _alice = RaceRunner(
  raceId: 1,
  runner:
      Runner(runnerId: 1, name: 'Alice Green', bibNumber: '412', grade: 11),
  team: _eagles,
);

DuplicateBibConflict _conflict(List<ConflictOccurrence> occurrences) =>
    DuplicateBibConflict(
        bibNumber: '412', runner: _alice, occurrences: occurrences);

Future<void> _pump(
  WidgetTester tester,
  DuplicateBibConflict conflict, {
  List<int>? assignmentsFor,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: DuplicateBibFlow(
          conflict: conflict,
          buildAssignment: (context, leftover) {
            assignmentsFor?.add(leftover.place);
            return Text('assign ${leftover.place}');
          },
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final twoFinishes = [
    const ConflictOccurrence(place: 8, time: '16:43.00'),
    const ConflictOccurrence(place: 12, time: '17:20.00'),
  ];

  testWidgets('asks which finish first', (tester) async {
    await _pump(tester, _conflict(twoFinishes));

    expect(find.textContaining('Which finish belongs'), findsOneWidget);
    expect(find.textContaining('Who finished'), findsNothing);
  });

  testWidgets('then asks who the other finish was', (tester) async {
    final assignments = <int>[];
    await _pump(tester, _conflict(twoFinishes),
        assignmentsFor: assignments);

    await tester.tap(find.text('8th place'));
    await tester.pumpAndSettle();

    expect(find.text('Alice Green finished 8th'), findsOneWidget);
    expect(find.text('Who finished 12th?'), findsOneWidget);
    expect(find.textContaining('17:20.00'), findsOneWidget);
    expect(find.textContaining('was a typo here'), findsOneWidget);
    expect(assignments, contains(12),
        reason: 'the leftover finish is the one being assigned');
  });

  testWidgets('the leftover is the one not chosen, whichever that is',
      (tester) async {
    final assignments = <int>[];
    await _pump(tester, _conflict(twoFinishes),
        assignmentsFor: assignments);

    await tester.tap(find.text('12th place'));
    await tester.pumpAndSettle();

    expect(find.text('Alice Green finished 12th'), findsOneWidget);
    expect(find.text('Who finished 8th?'), findsOneWidget);
    expect(assignments, contains(8));
  });

  testWidgets('says how many finishes are left when a bib was recorded thrice',
      (tester) async {
    await _pump(
      tester,
      _conflict([
        const ConflictOccurrence(place: 3, time: '15:10.00'),
        const ConflictOccurrence(place: 8, time: '16:43.00'),
        const ConflictOccurrence(place: 12, time: '17:20.00'),
      ]),
    );

    await tester.tap(find.text('3rd place'));
    await tester.pumpAndSettle();

    expect(find.text('Who finished 8th?'), findsOneWidget);
    expect(find.textContaining('2 finishes left'), findsOneWidget);
  });

  testWidgets('offers no way to delete the leftover finish', (tester) async {
    await _pump(tester, _conflict(twoFinishes));
    await tester.tap(find.text('8th place'));
    await tester.pumpAndSettle();

    // Somebody crossed the line there; only their bib was taken down wrong.
    // Deleting the finish would lose a runner the Timer has a time for.
    expect(find.textContaining('Remove'), findsNothing);
    expect(find.textContaining('Delete'), findsNothing);
  });
}
