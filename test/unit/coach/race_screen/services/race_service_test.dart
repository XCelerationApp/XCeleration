import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/race_screen/services/race_service.dart';
import 'package:xceleration/shared/models/database/i_master_race_resolver.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

// A race goes to the volunteers only once every team in it has runners. When
// it cannot, the coach is told which team is holding it up.

class _Race implements IMasterRaceResolver {
  _Race(this._teams, this._runners);

  final List<Team> _teams;
  final List<RaceRunner> _runners;

  @override
  Future<List<Team>> get teams async => _teams;

  @override
  Future<List<RaceRunner>> get raceRunners async => _runners;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _eagles = Team(teamId: 1, name: 'Eagles');
const _hawks = Team(teamId: 2, name: 'Hawks');
const _owls = Team(teamId: 3, name: 'Owls');

RaceRunner _on(Team team) => RaceRunner(
    raceId: 1,
    runner: Runner(runnerId: team.teamId, name: 'R', bibNumber: '1', grade: 10),
    team: team);

void main() {
  final service = RaceService();

  test('ready when every team has a runner', () async {
    final race = _Race([_eagles, _hawks], [_on(_eagles), _on(_hawks)]);

    expect(await service.whyRunnersNotReady(race), isNull);
    expect(await service.checkMinimumRunnersLoaded(race), isTrue);
  });

  test('names the team with no runners', () async {
    final race = _Race([_eagles, _hawks], [_on(_eagles)]);

    expect(await service.whyRunnersNotReady(race),
        'Hawks has no runners. Add runners, or take the team out of this race.');
    expect(await service.checkMinimumRunnersLoaded(race), isFalse);
  });

  test('names every team with no runners', () async {
    final race = _Race([_eagles, _hawks, _owls], [_on(_eagles)]);

    expect(await service.whyRunnersNotReady(race),
        'Hawks and Owls have no runners. Add runners, or take those teams out '
        'of this race.');
  });

  test('says so when the race has no runners at all', () async {
    expect(await service.whyRunnersNotReady(_Race([], [])),
        'This race has no runners yet. Add a team and its runners to '
        'continue.');
  });

  test('a runner\'s team counts even if the race was never linked to it',
      () async {
    // Races that came from another phone before those links synced.
    final race = _Race([], [_on(_eagles), _on(_hawks)]);

    expect(await service.whyRunnersNotReady(race), isNull);
  });
}
