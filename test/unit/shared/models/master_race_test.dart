import 'package:flutter/material.dart';
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

@GenerateMocks([
  IRaceRepository,
  IRunnerRepository,
  ITeamRepository,
  IResultsRepository,
])
import 'master_race_test.mocks.dart';

void main() {
  late MockIRaceRepository mockRaceRepo;
  late MockIRunnerRepository mockRunnerRepo;
  late MockITeamRepository mockTeamRepo;
  late MockIResultsRepository mockResultsRepo;

  // ── Fixtures ──────────────────────────────────────────────────────────────
  const raceId = 1;

  final testRace =
      Race(raceId: raceId, raceName: 'State Meet', flowState: Race.FLOW_PRE_RACE);
  final finishedRace =
      Race(raceId: raceId, raceName: 'State Meet', flowState: Race.FLOW_FINISHED);

  final teamA = Team(teamId: 1, name: 'Team A', abbreviation: 'TA', color: const Color(0xFF2196F3));
  final teamB = Team(teamId: 2, name: 'Team B', abbreviation: 'TB', color: const Color(0xFF4CAF50));

  final runnerAlice = Runner(runnerId: 10, name: 'Alice', bibNumber: '101', grade: 10);
  final runnerBob = Runner(runnerId: 11, name: 'Bob', bibNumber: '102', grade: 11);

  final participantAlice = RaceParticipant(raceId: raceId, runnerId: 10, teamId: 1);
  final participantBob = RaceParticipant(raceId: raceId, runnerId: 11, teamId: 2);

  setUp(() {
    mockRaceRepo = MockIRaceRepository();
    mockRunnerRepo = MockIRunnerRepository();
    mockTeamRepo = MockITeamRepository();
    mockResultsRepo = MockIResultsRepository();

    ServiceLocator.register<IRaceRepository>(mockRaceRepo);
    ServiceLocator.register<IRunnerRepository>(mockRunnerRepo);
    ServiceLocator.register<ITeamRepository>(mockTeamRepo);
    ServiceLocator.register<IResultsRepository>(mockResultsRepo);
  });

  tearDown(() {
    MasterRace.clearAllInstances();
    ServiceLocator.reset();
  });

  // ── getInstance / clearInstance / clearAllInstances ───────────────────────

  group('MasterRace', () {
    group('getInstance', () {
      test('returns the same instance for the same race ID', () {
        final a = MasterRace.getInstance(1);
        final b = MasterRace.getInstance(1);

        expect(identical(a, b), isTrue);
      });

      test('returns different instances for different race IDs', () {
        final a = MasterRace.getInstance(1);
        final b = MasterRace.getInstance(2);

        expect(identical(a, b), isFalse);
      });
    });

    group('clearInstance', () {
      test('removes the instance so a fresh one is returned on next get', () {
        final original = MasterRace.getInstance(1);
        MasterRace.clearInstance(1);
        final fresh = MasterRace.getInstance(1);

        expect(identical(original, fresh), isFalse);
      });

      test('is a no-op when called with an unknown race ID', () {
        expect(() => MasterRace.clearInstance(999), returnsNormally);
      });

      test('does not affect instances for other race IDs', () {
        final race2 = MasterRace.getInstance(2);
        MasterRace.getInstance(1);
        MasterRace.clearInstance(1);
        final race2Again = MasterRace.getInstance(2);

        expect(identical(race2, race2Again), isTrue);
      });
    });

    group('clearAllInstances', () {
      test('removes all cached instances', () {
        final a = MasterRace.getInstance(1);
        final b = MasterRace.getInstance(2);
        MasterRace.clearAllInstances();
        final aFresh = MasterRace.getInstance(1);
        final bFresh = MasterRace.getInstance(2);

        expect(identical(a, aFresh), isFalse);
        expect(identical(b, bFresh), isFalse);
      });
    });

    // ── Lazy loading: race ──────────────────────────────────────────────────

    group('race getter', () {
      test('fetches from repository on first access', () async {
        when(mockRaceRepo.getRace(raceId)).thenAnswer((_) async => testRace);
        final masterRace = MasterRace.getInstance(raceId);

        final result = await masterRace.race;

        expect(result, equals(testRace));
        verify(mockRaceRepo.getRace(raceId)).called(1);
      });

      test('returns cached value without hitting the repository again', () async {
        when(mockRaceRepo.getRace(raceId)).thenAnswer((_) async => testRace);
        final masterRace = MasterRace.getInstance(raceId);

        await masterRace.race;
        await masterRace.race;

        verify(mockRaceRepo.getRace(raceId)).called(1);
      });

      test('throws when repository returns null', () async {
        when(mockRaceRepo.getRace(raceId)).thenAnswer((_) async => null);
        final masterRace = MasterRace.getInstance(raceId);

        await expectLater(masterRace.race, throwsA(isA<Exception>()));
      });
    });

    // ── Lazy loading: raceParticipants ──────────────────────────────────────

    group('raceParticipants getter', () {
      test('fetches from repository on first access', () async {
        when(mockRaceRepo.getRaceParticipants(raceId))
            .thenAnswer((_) async => [participantAlice]);
        final masterRace = MasterRace.getInstance(raceId);

        final result = await masterRace.raceParticipants;

        expect(result, equals([participantAlice]));
        verify(mockRaceRepo.getRaceParticipants(raceId)).called(1);
      });

      test('returns cached value without hitting the repository again', () async {
        when(mockRaceRepo.getRaceParticipants(raceId))
            .thenAnswer((_) async => [participantAlice]);
        final masterRace = MasterRace.getInstance(raceId);

        await masterRace.raceParticipants;
        await masterRace.raceParticipants;

        verify(mockRaceRepo.getRaceParticipants(raceId)).called(1);
      });
    });

    // ── Lazy loading: teams ─────────────────────────────────────────────────

    group('teams getter', () {
      test('fetches from repository on first access', () async {
        when(mockRaceRepo.getRaceTeams(raceId))
            .thenAnswer((_) async => [teamA, teamB]);
        final masterRace = MasterRace.getInstance(raceId);

        final result = await masterRace.teams;

        expect(result, equals([teamA, teamB]));
        verify(mockRaceRepo.getRaceTeams(raceId)).called(1);
      });

      test('returns cached value without hitting the repository again', () async {
        when(mockRaceRepo.getRaceTeams(raceId))
            .thenAnswer((_) async => [teamA, teamB]);
        final masterRace = MasterRace.getInstance(raceId);

        await masterRace.teams;
        await masterRace.teams;

        verify(mockRaceRepo.getRaceTeams(raceId)).called(1);
      });
    });

    // ── Lazy loading: raceRunners ───────────────────────────────────────────

    group('raceRunners getter', () {
      setUp(() {
        when(mockRaceRepo.getRaceParticipants(raceId))
            .thenAnswer((_) async => [participantAlice, participantBob]);
        when(mockRunnerRepo.getRunner(10)).thenAnswer((_) async => runnerAlice);
        when(mockRunnerRepo.getRunner(11)).thenAnswer((_) async => runnerBob);
        when(mockTeamRepo.getTeam(1)).thenAnswer((_) async => teamA);
        when(mockTeamRepo.getTeam(2)).thenAnswer((_) async => teamB);
      });

      test('returns runners built from participants', () async {
        final masterRace = MasterRace.getInstance(raceId);

        final result = await masterRace.raceRunners;

        expect(result, hasLength(2));
        expect(result.map((r) => r.runner.runnerId), containsAll([10, 11]));
      });

      test('returns cached value without hitting the repository again', () async {
        final masterRace = MasterRace.getInstance(raceId);

        await masterRace.raceRunners;
        await masterRace.raceRunners;

        verify(mockRaceRepo.getRaceParticipants(raceId)).called(1);
      });

      test('returns empty list when race has no participants', () async {
        when(mockRaceRepo.getRaceParticipants(raceId))
            .thenAnswer((_) async => []);
        final masterRace = MasterRace.getInstance(raceId);

        final result = await masterRace.raceRunners;

        expect(result, isEmpty);
      });
    });

    // ── teamtoRaceRunnersMap ────────────────────────────────────────────────

    group('teamtoRaceRunnersMap', () {
      test('groups runners under their correct team', () async {
        when(mockRaceRepo.getRaceTeams(raceId)).thenAnswer((_) async => [teamA]);
        when(mockRaceRepo.getRaceParticipants(raceId))
            .thenAnswer((_) async => [participantAlice]);
        when(mockRunnerRepo.getRunner(10)).thenAnswer((_) async => runnerAlice);
        when(mockTeamRepo.getTeam(1)).thenAnswer((_) async => teamA);

        final masterRace = MasterRace.getInstance(raceId);
        final result = await masterRace.teamtoRaceRunnersMap;

        expect(result.keys, contains(teamA));
        expect(result[teamA], hasLength(1));
        expect(result[teamA]!.first.runner.runnerId, 10);
      });

      test('includes teams with zero runners', () async {
        // teamB has no participants
        when(mockRaceRepo.getRaceTeams(raceId))
            .thenAnswer((_) async => [teamA, teamB]);
        when(mockRaceRepo.getRaceParticipants(raceId))
            .thenAnswer((_) async => [participantAlice]);
        when(mockRunnerRepo.getRunner(10)).thenAnswer((_) async => runnerAlice);
        when(mockTeamRepo.getTeam(1)).thenAnswer((_) async => teamA);

        final masterRace = MasterRace.getInstance(raceId);
        final result = await masterRace.teamtoRaceRunnersMap;

        expect(result.keys, contains(teamB));
        expect(result[teamB], isEmpty);
      });

      test('uses the Team instance from teamsList as the map key', () async {
        // getTeam returns a different object (same teamId, different name)
        final teamAFromRepo = Team(
          teamId: 1,
          name: 'Team A (repo variant)',
          abbreviation: 'TAR',
          color: const Color(0xFF2196F3),
        );

        when(mockRaceRepo.getRaceTeams(raceId)).thenAnswer((_) async => [teamA]);
        when(mockRaceRepo.getRaceParticipants(raceId))
            .thenAnswer((_) async => [participantAlice]);
        when(mockRunnerRepo.getRunner(10)).thenAnswer((_) async => runnerAlice);
        when(mockTeamRepo.getTeam(1)).thenAnswer((_) async => teamAFromRepo);

        final masterRace = MasterRace.getInstance(raceId);
        final result = await masterRace.teamtoRaceRunnersMap;

        // Key should be teamA (from getRaceTeams), not teamAFromRepo
        expect(result.keys.first, equals(teamA));
      });

      test('returns cached map without rebuilding on second access', () async {
        when(mockRaceRepo.getRaceTeams(raceId)).thenAnswer((_) async => [teamA]);
        when(mockRaceRepo.getRaceParticipants(raceId))
            .thenAnswer((_) async => [participantAlice]);
        when(mockRunnerRepo.getRunner(10)).thenAnswer((_) async => runnerAlice);
        when(mockTeamRepo.getTeam(1)).thenAnswer((_) async => teamA);

        final masterRace = MasterRace.getInstance(raceId);
        await masterRace.teamtoRaceRunnersMap;
        await masterRace.teamtoRaceRunnersMap;

        verify(mockRaceRepo.getRaceTeams(raceId)).called(1);
      });
    });

    // ── filteredSearchResults ───────────────────────────────────────────────

    group('filteredSearchResults', () {
      setUp(() {
        when(mockRaceRepo.getRaceTeams(raceId)).thenAnswer((_) async => [teamA]);
        when(mockRaceRepo.getRaceParticipants(raceId))
            .thenAnswer((_) async => [participantAlice]);
        when(mockRunnerRepo.getRunner(10)).thenAnswer((_) async => runnerAlice);
        when(mockTeamRepo.getTeam(1)).thenAnswer((_) async => teamA);
      });

      test('returns teamtoRaceRunnersMap when no search is active', () async {
        final masterRace = MasterRace.getInstance(raceId);

        final filtered = await masterRace.filteredSearchResults;
        final all = await masterRace.teamtoRaceRunnersMap;

        expect(filtered, equals(all));
      });

      test('returns only matching runners after a non-empty query', () async {
        final masterRace = MasterRace.getInstance(raceId);

        await masterRace.searchRaceRunners('Bob'); // no runner named Bob

        final filtered = await masterRace.filteredSearchResults;
        expect(filtered.values.expand((v) => v), isEmpty);
      });

      test('returns all runners after an empty query resets the filter', () async {
        final masterRace = MasterRace.getInstance(raceId);

        await masterRace.searchRaceRunners('Bob'); // narrow
        await masterRace.searchRaceRunners(''); // reset

        final filtered = await masterRace.filteredSearchResults;
        expect(filtered.values.expand((v) => v).length, 1);
      });

      test('returns matching runner when query matches by name', () async {
        final masterRace = MasterRace.getInstance(raceId);

        await masterRace.searchRaceRunners('Alice');

        final filtered = await masterRace.filteredSearchResults;
        expect(filtered.values.expand((v) => v).length, 1);
        expect(
          filtered.values.expand((v) => v).first.runner.name,
          'Alice',
        );
      });
    });

    // ── results getter ──────────────────────────────────────────────────────

    group('results getter', () {
      test('throws when race flowState is not FLOW_FINISHED', () async {
        when(mockRaceRepo.getRace(raceId)).thenAnswer((_) async => testRace);
        final masterRace = MasterRace.getInstance(raceId);

        await expectLater(masterRace.results, throwsA(isA<Exception>()));
      });

      test('returns results list when race is finished', () async {
        final r1 = RaceResult(raceId: raceId, place: 1);
        final r2 = RaceResult(raceId: raceId, place: 2);

        when(mockRaceRepo.getRace(raceId)).thenAnswer((_) async => finishedRace);
        when(mockResultsRepo.getRaceResults(raceId))
            .thenAnswer((_) async => [r1, r2]);

        final masterRace = MasterRace.getInstance(raceId);
        final results = await masterRace.results;

        expect(results, hasLength(2));
      });

      test('fetches results from repository only once', () async {
        final r1 = RaceResult(raceId: raceId, place: 1);

        when(mockRaceRepo.getRace(raceId)).thenAnswer((_) async => finishedRace);
        when(mockResultsRepo.getRaceResults(raceId))
            .thenAnswer((_) async => [r1]);

        final masterRace = MasterRace.getInstance(raceId);
        await masterRace.results;
        await masterRace.results;

        verify(mockResultsRepo.getRaceResults(raceId)).called(1);
      });
    });

    // ── getRaceRunnerFromRaceParticipant ────────────────────────────────────

    group('getRaceRunnerFromRaceParticipant', () {
      test('builds a RaceRunner from runner and team repositories', () async {
        when(mockRunnerRepo.getRunner(10)).thenAnswer((_) async => runnerAlice);
        when(mockTeamRepo.getTeam(1)).thenAnswer((_) async => teamA);

        final masterRace = MasterRace.getInstance(raceId);
        final result = await masterRace.getRaceRunnerFromRaceParticipant(participantAlice);

        expect(result, isNotNull);
        expect(result!.runner.runnerId, 10);
        expect(result.team.teamId, 1);
        expect(result.raceId, raceId);
      });

      test('returns cached value without hitting repositories on second call',
          () async {
        when(mockRunnerRepo.getRunner(10)).thenAnswer((_) async => runnerAlice);
        when(mockTeamRepo.getTeam(1)).thenAnswer((_) async => teamA);

        final masterRace = MasterRace.getInstance(raceId);
        await masterRace.getRaceRunnerFromRaceParticipant(participantAlice);
        await masterRace.getRaceRunnerFromRaceParticipant(participantAlice);

        verify(mockRunnerRepo.getRunner(10)).called(1);
        verify(mockTeamRepo.getTeam(1)).called(1);
      });

      test('throws when runner is not found in repository', () async {
        when(mockRunnerRepo.getRunner(10)).thenAnswer((_) async => null);

        final masterRace = MasterRace.getInstance(raceId);

        await expectLater(
          masterRace.getRaceRunnerFromRaceParticipant(participantAlice),
          throwsA(isA<Exception>()),
        );
      });

      test('throws when team is not found in repository', () async {
        when(mockRunnerRepo.getRunner(10)).thenAnswer((_) async => runnerAlice);
        when(mockTeamRepo.getTeam(1)).thenAnswer((_) async => null);

        final masterRace = MasterRace.getInstance(raceId);

        await expectLater(
          masterRace.getRaceRunnerFromRaceParticipant(participantAlice),
          throwsA(isA<Exception>()),
        );
      });

      test('caches different participants independently', () async {
        when(mockRunnerRepo.getRunner(10)).thenAnswer((_) async => runnerAlice);
        when(mockRunnerRepo.getRunner(11)).thenAnswer((_) async => runnerBob);
        when(mockTeamRepo.getTeam(1)).thenAnswer((_) async => teamA);
        when(mockTeamRepo.getTeam(2)).thenAnswer((_) async => teamB);

        final masterRace = MasterRace.getInstance(raceId);
        final resultA =
            await masterRace.getRaceRunnerFromRaceParticipant(participantAlice);
        final resultB =
            await masterRace.getRaceRunnerFromRaceParticipant(participantBob);

        expect(resultA!.runner.runnerId, 10);
        expect(resultB!.runner.runnerId, 11);
      });
    });
  });
}
