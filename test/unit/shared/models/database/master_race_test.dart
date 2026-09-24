import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/core/repositories/i_race_repository.dart';
import 'package:xceleration/core/repositories/i_results_repository.dart';
import 'package:xceleration/core/repositories/i_runner_repository.dart';
import 'package:xceleration/core/repositories/i_team_repository.dart';
import 'package:xceleration/core/services/service_locator.dart';
import 'package:xceleration/shared/models/database/base_models.dart';
import 'package:xceleration/shared/models/database/master_race.dart';

@GenerateMocks(
    [IRaceRepository, IRunnerRepository, ITeamRepository, IResultsRepository])
import 'master_race_test.mocks.dart';

void main() {
  late MockIRaceRepository races;
  late MockIRunnerRepository runners;
  late MockITeamRepository teams;
  const team = Team(teamId: 1, name: 'Eagles');

  setUp(() {
    races = MockIRaceRepository();
    runners = MockIRunnerRepository();
    teams = MockITeamRepository();
    ServiceLocator.register<IRaceRepository>(races);
    ServiceLocator.register<IRunnerRepository>(runners);
    ServiceLocator.register<ITeamRepository>(teams);
    ServiceLocator.register<IResultsRepository>(MockIResultsRepository());
    when(teams.getTeam(1)).thenAnswer((_) async => team);
    for (var i = 1; i <= 3; i++) {
      when(runners.getRunner(i)).thenAnswer((_) async =>
          Runner(runnerId: i, name: 'R$i', bibNumber: '$i', grade: 10));
    }
    when(races.getRaceParticipants(7)).thenAnswer((_) async => [
          for (var i = 1; i <= 3; i++)
            RaceParticipant(raceId: 7, runnerId: i, teamId: 1),
        ]);
  });

  tearDown(() {
    MasterRace.clearAllInstances();
    ServiceLocator.reset();
  });

  test('a cache reset while runners are being grouped does not list them '
      'twice', () async {
    // The first team lookup waits, so a second build can start after a
    // cache reset while the first one is still running.
    final firstLookup = Completer<List<Team>>();
    var calls = 0;
    when(races.getRaceTeams(7)).thenAnswer(
        (_) => ++calls == 1 ? firstLookup.future : Future.value([team]));
    final masterRace = MasterRace.getInstance(7);

    final first = masterRace.teamtoRaceRunnersMap;
    await Future<void>.delayed(Duration.zero);
    masterRace.invalidateCache(); // e.g. a runner was just added
    final second = masterRace.teamtoRaceRunnersMap;
    firstLookup.complete([team]);
    await Future.wait([first, second]);

    final grouped = await masterRace.teamtoRaceRunnersMap;
    expect(grouped.values.single.map((r) => r.runner.runnerId), [1, 2, 3]);
  });
}
