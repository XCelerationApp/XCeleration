import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/race_results/edit/edit_results_controller.dart';
import 'package:xceleration/shared/models/database/race_result.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

// Correcting a finished race. Every test checks what would be saved — who is
// at each place, with which time — since that is what the results show.

const _eagles = Team(teamId: 1, name: 'Eagles');

RaceRunner _runner(int id, String name) => RaceRunner(
      raceId: 7,
      runner: Runner(runnerId: id, name: name, bibNumber: '${100 + id}', grade: 10),
      team: _eagles,
    );

final _ann = _runner(1, 'Ann');
final _bo = _runner(2, 'Bo');
final _cy = _runner(3, 'Cy');
final _di = _runner(4, 'Di'); // in the race, did not finish

Duration _t(int s) => Duration(minutes: 15, seconds: s);

void main() {
  late List<RaceResult>? saved;

  EditResultsController make({Future<void> Function(List<RaceResult>)? save}) =>
      EditResultsController(
        raceId: 7,
        results: [
          // Out of order on purpose: places decide the order.
          RaceResult(raceId: 7, runner: _cy.runner, team: _eagles, place: 3, finishTime: _t(30)),
          RaceResult(raceId: 7, runner: _ann.runner, team: _eagles, place: 1, finishTime: _t(10)),
          RaceResult(raceId: 7, runner: _bo.runner, team: _eagles, place: 2, finishTime: _t(20)),
        ],
        raceRunners: [_di, _cy, _bo, _ann],
        save: save ?? (results) async => saved = results,
      );

  setUp(() => saved = null);

  Future<List<String>> savedOrder(EditResultsController c) async {
    expect(await c.save(), isTrue);
    return [
      for (final r in saved!)
        '${r.place} ${r.runner!.name} ${r.finishTime!.inSeconds - 900}'
    ];
  }

  test('starts from the results in finish order', () async {
    final c = make();

    expect(await savedOrder(c), ['1 Ann 10', '2 Bo 20', '3 Cy 30']);
    expect(c.hasChanges, isFalse);
  });

  group('changing who finished', () {
    test('someone who did not finish takes the place and its time', () async {
      // Bo's bib was really Di's.
      final c = make()..assignRunner(1, _di);

      expect(await savedOrder(c), ['1 Ann 10', '2 Di 20', '3 Cy 30']);
    });

    test('someone already placed swaps with whoever was there', () async {
      final c = make()..assignRunner(0, _cy);

      expect(await savedOrder(c), ['1 Cy 10', '2 Bo 20', '3 Ann 30'],
          reason: 'times stay with the places');
    });

    test('picking the same runner changes nothing', () {
      final c = make()..assignRunner(0, _ann);

      expect(c.hasChanges, isFalse);
    });
  });

  group('changing a time', () {
    test('a time between its neighbours is taken', () async {
      final c = make();

      expect(c.changeTime(1, _t(25)), isNull);

      expect(await savedOrder(c), ['1 Ann 10', '2 Bo 25', '3 Cy 30']);
    });

    test('a time before the finisher ahead is refused', () {
      final c = make();

      expect(c.changeTime(1, _t(5)), contains('1st place'));
      expect(c.hasChanges, isFalse);
    });

    test('a time after the finisher behind is refused', () {
      final c = make();

      expect(c.changeTime(1, _t(40)), contains('3rd place'));
      expect(c.hasChanges, isFalse);
    });

    test('the same time as a neighbour is refused', () {
      // Times go to the hundredth: two finishers never share one.
      final c = make();
      expect(c.changeTime(1, _t(10)), contains('after 1st place'));
      expect(c.changeTime(1, _t(30)), contains('before 3rd place'));
      expect(c.hasChanges, isFalse);
    });
  });

  test('removing a finisher moves everyone after them up', () async {
    final c = make()..remove(0);

    expect(await savedOrder(c), ['1 Bo 20', '2 Cy 30']);
    expect(c.placeOf(_ann), isNull);
  });

  test('undo takes back the last change, one at a time', () async {
    final c = make()
      ..assignRunner(1, _di)
      ..remove(0);
    expect(c.undoLabel, 'Remove Ann');

    c.undo();
    expect(c.undoLabel, 'Di at 2nd');
    c.undo();

    expect(c.hasChanges, isFalse);
    expect(await savedOrder(c), ['1 Ann 10', '2 Bo 20', '3 Cy 30']);
  });

  test('a failed save keeps the changes and says why', () async {
    final c = make(save: (_) async => throw Exception('disk full'))
      ..remove(0);

    expect(await c.save(), isFalse);

    expect(c.error?.userMessage, 'Could not save the results. Please try again.');
    expect(c.hasChanges, isTrue, reason: 'so the coach can try again');
  });

  test('runners to choose from are listed by bib', () {
    expect(make().raceRunners.map((r) => r.runner.name), ['Ann', 'Bo', 'Cy', 'Di']);
  });
}
