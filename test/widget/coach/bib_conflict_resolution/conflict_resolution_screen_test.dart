import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/bib_conflict_resolution/controller/conflict_resolution_controller.dart';
import 'package:xceleration/coach/bib_conflict_resolution/model/bib_conflict.dart';
import 'package:xceleration/coach/bib_conflict_resolution/screen/conflict_resolution_screen.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

// The bib conflict screen, end to end: it is reached from a race's results,
// and what it hands back is who finished at each place it settled.

const _eagles = Team(teamId: 1, name: 'Eagles', abbreviation: 'EAG');

RaceRunner _runner(int id, String bib, String name) => RaceRunner(
      raceId: 1,
      runner: Runner(runnerId: id, name: name, bibNumber: bib, grade: 11),
      team: _eagles,
    );

final _quinn = _runner(1, '959', 'Quinn Owls');
final _gray = _runner(2, '949', 'Gray Eagles');
final _nico = _runner(3, '956', 'Nico Hawks');

final _duplicate = DuplicateBibConflict(
  bibNumber: '959',
  runner: _quinn,
  occurrences: const [
    ConflictOccurrence(place: 16, nearby: [
      NearbyFinisher(place: 15, name: 'Finley Eagles', team: 'Eagles', bibNumber: '944'),
      NearbyFinisher(place: 18, name: 'Emery Eagles', team: 'Eagles', bibNumber: '945'),
    ]),
    ConflictOccurrence(place: 21, time: '16:03.78', nearby: [
      NearbyFinisher(place: 20, name: 'Morgan Hawks', team: 'Hawks', bibNumber: '957'),
    ]),
  ],
);

const _unknown = UnknownBibConflict(
  bibNumber: '9567',
  occurrence: ConflictOccurrence(place: 17),
);

ConflictResolutionController _controller() => ConflictResolutionController(
      conflicts: [_duplicate, _unknown],
      candidates: [_gray, _nico],
      knownBibs: {'959', '949', '956'},
      teams: const ['Eagles'],
      raceName: 'Invitational',
      createRunner: (_) async => Success(_nico),
    );

void main() {
  late ConflictResolutionController controller;
  Object? popped;
  var didPop = false;

  Future<void> open(WidgetTester tester) async {
    controller = _controller();
    popped = null;
    didPop = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                popped = await ConflictResolutionScreen.open(context,
                    create: () => controller);
                didPop = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Start Resolving'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Resolving'));
    await tester.pumpAndSettle();
  }

  testWidgets('the summary lists every conflict, in finish order',
      (tester) async {
    await open(tester);

    expect(find.text('1 duplicate bib · 1 unknown bib'), findsOneWidget);
    expect(find.text('#959'), findsOneWidget);
    expect(find.text('Recorded 16th, 21st'), findsOneWidget);
    expect(find.text('#9567'), findsOneWidget);
  });

  testWidgets('only describes the kinds of conflict the race has',
      (tester) async {
    controller = ConflictResolutionController(
      conflicts: [_duplicate],
      candidates: [_gray],
      knownBibs: const {},
      teams: const ['Eagles'],
      raceName: 'Invitational',
      createRunner: (_) async => Success(_gray),
    );
    await tester.pumpWidget(MaterialApp(
      home: ConflictResolutionScreen(create: () => controller),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Duplicate Bibs'), findsOneWidget);
    expect(find.text('Unknown Bibs'), findsNothing);
  });

  testWidgets('any conflict can be done first', (tester) async {
    await open(tester);

    await tester.tap(find.text('#9567'));
    await tester.pumpAndSettle();

    expect(find.text('UNKNOWN BIB'), findsOneWidget);
    // In the header and again in the nearby panel.
    expect(find.text('17th'), findsNWidgets(2));
  });

  testWidgets('shows the race it is resolving', (tester) async {
    await open(tester);
    await start(tester);

    expect(find.text('Invitational'), findsOneWidget);
  });

  testWidgets('back from a conflict returns to the summary', (tester) async {
    await open(tester);
    await start(tester);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Start Resolving'), findsOneWidget);
  });

  testWidgets('back from the summary leaves without submitting',
      (tester) async {
    await open(tester);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(didPop, isTrue);
    expect(popped, isNull);
  });

  testWidgets('a repeated bib asks which finish, then who the other was',
      (tester) async {
    await open(tester);
    await start(tester);

    expect(find.text('DUPLICATE BIB'), findsOneWidget);
    expect(find.text('Quinn Owls'), findsOneWidget);
    expect(find.text('16th place'), findsOneWidget);
    expect(find.text('21st place'), findsOneWidget);
    // 16th has no settled time; it says so rather than guessing.
    expect(find.text('Time not settled'), findsOneWidget);
    expect(find.text('16:03.78'), findsOneWidget);

    await tester.tap(find.text('16th place'));
    await tester.pumpAndSettle();

    expect(find.text('16th place is correct'), findsOneWidget);
    expect(find.text('Who finished 21st?'), findsOneWidget);
    expect(find.textContaining('Bib #959 was a typo here'), findsOneWidget);
    // Not "unknown": 959 is Quinn's bib, just not at this finish.
    expect(find.text('UNKNOWN BIB'), findsNothing);
    // Nearby: the runner ahead, then this finish, each with its place.
    expect(find.text('20th'), findsOneWidget);
    expect(find.text('Morgan Hawks'), findsOneWidget);
    expect(find.text('Unknown runner'), findsOneWidget);
    expect(find.text('Assign Existing Runner'), findsOneWidget);
    expect(find.text('Create New Runner'), findsOneWidget);
  });

  testWidgets('submitting hands back who finished at each place',
      (tester) async {
    await open(tester);
    controller.startResolving();
    controller.chooseDuplicateOccurrence(16);
    controller.prepareAssignForDuplicate(_gray, '21st');
    await controller.commitPending();
    controller.prepareAssign(_nico, '17th');
    await controller.commitPending();
    await tester.pumpAndSettle();

    expect(find.text('All conflicts resolved'), findsOneWidget);
    expect(find.text('16th place · Bib #959'), findsOneWidget);
    expect(find.textContaining('Kept: Quinn Owls'), findsOneWidget);
    expect(find.textContaining('Assigned: Gray Eagles'), findsOneWidget);

    await tester.ensureVisible(find.text('Confirm & Submit Results'));
    await tester.tap(find.text('Confirm & Submit Results'));
    await tester.pumpAndSettle();

    expect(popped, {16: _quinn, 17: _nico, 21: _gray});
  });

  testWidgets('both cards fit on a phone', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await open(tester);
    await start(tester);
    await tester.tap(find.text('16th place'));
    await tester.pumpAndSettle();

    // A RenderFlex overflow fails the test.
    expect(find.text('Who finished 21st?'), findsOneWidget);
  });

  for (final (name, size) in const [
    ('iPhone 13 Pro', Size(390, 844)),
    ('iPhone SE', Size(375, 667)),
  ]) {
    testWidgets('every stage fits on an $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // A RenderFlex overflow at any stage fails the test.
      await open(tester);
      await start(tester);
      await tester.tap(find.text('16th place'));
      await tester.pumpAndSettle();
      controller.prepareAssignForDuplicate(_gray, '21st');
      await controller.commitPending();
      await tester.pumpAndSettle();
      expect(find.text('UNKNOWN BIB'), findsOneWidget);
      controller.prepareAssign(_nico, '17th');
      await tester.pumpAndSettle();
      await controller.commitPending();
      await tester.pumpAndSettle();
      expect(find.text('All conflicts resolved'), findsOneWidget);
    });
  }
}
