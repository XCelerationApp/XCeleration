import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/bib_conflict_resolution/services/runner_creator.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/shared/models/database/base_models.dart';
import 'package:xceleration/shared/models/database/master_race.dart';

import 'runner_creator_test.mocks.dart';

// Adding a runner the coach met while resolving a bib: they have to end up
// saved, on their team, and entered in this race, or the finish they are
// given points at nobody.

@GenerateMocks([MasterRace])
void main() {
  late MockMasterRace masterRace;
  const eagles = Team(
    teamId: 7,
    name: 'Eagles',
    abbreviation: 'EAG',
    color: Color(0xFF1565C0),
  );

  const newRunner = NewRunner(
    name: 'Avery Stone',
    bibNumber: '412',
    teamName: 'Eagles',
    grade: 10,
  );

  setUp(() {
    masterRace = MockMasterRace();
    when(masterRace.raceId).thenReturn(3);
    when(masterRace.teams).thenAnswer((_) async => [eagles]);
    when(masterRace.getRunnerByBib(any)).thenAnswer((_) async => null);
    when(masterRace.createRunner(any)).thenAnswer((_) async => 55);
    when(masterRace.addRunnerToTeam(any, any)).thenAnswer((_) async {});
    when(masterRace.addRaceParticipant(any)).thenAnswer((_) async {});
    when(masterRace.raceRunners).thenAnswer((_) async => []);
    when(masterRace.addTeamParticipant(any)).thenAnswer((_) async {});
  });

  test('saves the runner, puts them on the team and enters them', () async {
    final result = await saveNewRunner(masterRace, newRunner);

    final saved = (result as Success).value;
    expect(saved.runner.runnerId, 55);
    expect(saved.runner.name, 'Avery Stone');
    expect(saved.runner.bibNumber, '412');
    expect(saved.team.teamId, 7);
    verify(masterRace.addRunnerToTeam(7, 55)).called(1);
    final entered =
        verify(masterRace.addRaceParticipant(captureAny)).captured.single
            as RaceParticipant;
    expect(entered.raceId, 3);
    expect(entered.runnerId, 55);
    expect(entered.teamId, 7);
  });

  test('reuses a runner already saved with that bib', () async {
    // On the roster, just not entered in this race.
    when(masterRace.getRunnerByBib('412')).thenAnswer(
      (_) async => const Runner(
        runnerId: 9,
        name: 'Avery Stone',
        bibNumber: '412',
        grade: 10,
      ),
    );

    final result = await saveNewRunner(masterRace, newRunner);

    expect((result as Success).value.runner.runnerId, 9);
    verifyNever(masterRace.createRunner(any));
  });

  test('refuses a bib that is already someone else\'s', () async {
    // Giving the finish to runner 9 would credit the wrong person.
    when(masterRace.getRunnerByBib('412')).thenAnswer(
      (_) async => const Runner(
        runnerId: 9,
        name: 'Jordan Lee',
        bibNumber: '412',
        grade: 11,
      ),
    );

    final result = await saveNewRunner(masterRace, newRunner);

    expect((result as Failure).error.userMessage, contains('Jordan Lee'));
    verifyNever(masterRace.createRunner(any));
    verifyNever(masterRace.addRaceParticipant(any));
  });

  test('reuses the saved runner whatever the capitals', () async {
    when(masterRace.getRunnerByBib('412')).thenAnswer(
      (_) async => const Runner(
        runnerId: 9,
        name: 'avery stone ',
        bibNumber: '412',
        grade: 10,
      ),
    );

    final result = await saveNewRunner(masterRace, newRunner);

    expect((result as Success).value.runner.runnerId, 9);
  });

  test('says so when the team is not in the race', () async {
    final result = await saveNewRunner(
      masterRace,
      const NewRunner(
        name: 'Avery Stone',
        bibNumber: '412',
        teamName: 'Owls',
        grade: 10,
      ),
    );

    expect((result as Failure).error.userMessage, contains('Owls'));
    verifyNever(masterRace.createRunner(any));
  });

  test('reports a failed save instead of throwing', () async {
    when(masterRace.createRunner(any)).thenThrow(Exception('disk full'));

    final result = await saveNewRunner(masterRace, newRunner);

    expect(result, isA<Failure>());
  });

  // A race whose runners were entered but whose teams were not: the Team
  // menu for a new runner was empty and could not be opened.
  group('a team known only from the race\'s runners', () {
    const hawks = Team(teamId: 8, name: 'Hawks', abbreviation: 'HAW');

    setUp(() {
      when(masterRace.teams).thenAnswer((_) async => []);
      when(masterRace.raceRunners).thenAnswer(
        (_) async => [
          RaceRunner(
            raceId: 3,
            runner: const Runner(runnerId: 1, name: 'Mia', bibNumber: '1'),
            team: hawks,
          ),
          RaceRunner(
            raceId: 3,
            runner: const Runner(runnerId: 2, name: 'Zoe', bibNumber: '2'),
            team: hawks,
          ),
        ],
      );
    });

    test('is offered, once', () async {
      final teams = await teamsForNewRunner(masterRace);

      expect(teams.map((t) => t.name), ['Hawks']);
    });

    test('can be chosen, and joins the race', () async {
      final result = await saveNewRunner(
        masterRace,
        const NewRunner(
          name: 'Avery Stone',
          bibNumber: '412',
          teamName: 'Hawks',
          grade: 10,
        ),
      );

      expect((result as Success).value.team.teamId, 8);
      final joined =
          verify(masterRace.addTeamParticipant(captureAny)).captured.single
              as TeamParticipant;
      expect((joined.raceId, joined.teamId), (3, 8));
    });
  });

  test('a team already in the race is not entered again', () async {
    await saveNewRunner(masterRace, newRunner);

    verifyNever(masterRace.addTeamParticipant(any));
  });
}
