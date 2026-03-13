import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/core/repositories/i_race_repository.dart';
import 'package:xceleration/core/repositories/i_results_repository.dart';
import 'package:xceleration/core/repositories/i_runner_repository.dart';
import 'package:xceleration/core/repositories/i_team_repository.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/race_share_importer.dart';
import 'package:xceleration/shared/models/database/base_models.dart';

@GenerateMocks([IRunnerRepository, ITeamRepository, IRaceRepository, IResultsRepository])
import 'race_share_importer_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RaceShareImporter importer;
  late MockIRunnerRepository mockRunners;
  late MockITeamRepository mockTeams;
  late MockIRaceRepository mockRaces;
  late MockIResultsRepository mockResults;

  const int kRaceId = 1;
  const int kTeamId = 10;
  const int kRunnerId = 20;

  final Runner fakeRunner = Runner(
    runnerId: kRunnerId,
    name: 'Alice',
    bibNumber: '100',
    grade: 11,
  );

  setUp(() {
    mockRunners = MockIRunnerRepository();
    mockTeams = MockITeamRepository();
    mockRaces = MockIRaceRepository();
    mockResults = MockIResultsRepository();
    importer = RaceShareImporter(
      runners: mockRunners,
      teams: mockTeams,
      races: mockRaces,
      results: mockResults,
    );
  });

  String buildPayload({
    String type = 'RACE_SHARE_V1',
    Map<String, dynamic>? race,
    List<dynamic>? teams,
    List<dynamic>? individualResults,
  }) {
    return jsonEncode({
      'type': type,
      'race': race ??
          {
            'name': 'Test Race',
            'race_date': '2024-09-01',
            'location': 'Springfield',
            'distance': 5.0,
            'distance_unit': 'km',
          },
      'teams': teams ?? [],
      'individual_results': individualResults ?? [],
    });
  }

  group('RaceShareImporter', () {
    group('importFromJson', () {
      test('returns Success when import completes', () async {
        when(mockRaces.createRace(any)).thenAnswer((_) async => kRaceId);

        final result = await importer.importFromJson(buildPayload());

        expect(result, isA<Success<void>>());
      });

      test('returns Failure for unsupported payload type', () async {
        final result =
            await importer.importFromJson(buildPayload(type: 'RACE_SHARE_V2'));

        expect(result, isA<Failure<void>>());
        final error = (result as Failure).error;
        expect(error.userMessage, contains('not supported'));
        verifyNever(mockRaces.createRace(any));
      });

      test('creates race with (shared) suffix', () async {
        when(mockRaces.createRace(any)).thenAnswer((_) async => kRaceId);

        await importer.importFromJson(buildPayload());

        final captured =
            verify(mockRaces.createRace(captureAny)).captured.single as Race;
        expect(captured.raceName, 'Test Race (shared)');
        expect(captured.flowState, Race.FLOW_FINISHED);
      });

      test('creates new team when team does not exist', () async {
        when(mockRaces.createRace(any)).thenAnswer((_) async => kRaceId);
        when(mockTeams.getTeamByName(any)).thenAnswer((_) async => null);
        when(mockTeams.createTeam(any)).thenAnswer((_) async => kTeamId);
        when(mockRaces.addTeamParticipantToRace(any)).thenAnswer((_) async {});

        final payload = buildPayload(teams: [
          {'name': 'Tigers', 'abbreviation': 'TIG', 'color': 0xFF0000},
        ]);

        final result = await importer.importFromJson(payload);

        expect(result, isA<Success<void>>());
        verify(mockTeams.getTeamByName('Tigers')).called(1);
        verify(mockTeams.createTeam(any)).called(1);
        verify(mockRaces.addTeamParticipantToRace(any)).called(1);
      });

      test('reuses existing team without creating duplicate', () async {
        final existingTeam = Team(teamId: kTeamId, name: 'Tigers');
        when(mockRaces.createRace(any)).thenAnswer((_) async => kRaceId);
        when(mockTeams.getTeamByName('Tigers'))
            .thenAnswer((_) async => existingTeam);
        when(mockRaces.addTeamParticipantToRace(any)).thenAnswer((_) async {});

        final payload = buildPayload(teams: [
          {'name': 'Tigers'},
        ]);

        await importer.importFromJson(payload);

        verifyNever(mockTeams.createTeam(any));
      });

      test('creates runner and result for individual result entry', () async {
        when(mockRaces.createRace(any)).thenAnswer((_) async => kRaceId);
        when(mockRunners.getRunnerByBib('100')).thenAnswer((_) async => null);
        when(mockRunners.createRunner(any)).thenAnswer((_) async => kRunnerId);
        when(mockRunners.getRunner(kRunnerId)).thenAnswer((_) async => fakeRunner);
        when(mockRunners.getRunnerTeams(kRunnerId)).thenAnswer((_) async => []);
        when(mockRaces.addRaceParticipant(any)).thenAnswer((_) async {});
        when(mockResults.addRaceResult(any)).thenAnswer((_) async {});

        final payload = buildPayload(individualResults: [
          {
            'name': 'Alice',
            'bib_number': '100',
            'grade': 11,
            'finish_time_ms': 1200000,
            'place': 1,
          },
        ]);

        final result = await importer.importFromJson(payload);

        expect(result, isA<Success<void>>());
        verify(mockRunners.createRunner(any)).called(1);
        verify(mockRaces.addRaceParticipant(any)).called(1);
        verify(mockResults.addRaceResult(any)).called(1);
      });

      test('reuses existing runner without creating duplicate', () async {
        when(mockRaces.createRace(any)).thenAnswer((_) async => kRaceId);
        when(mockRunners.getRunnerByBib('100')).thenAnswer((_) async => fakeRunner);
        when(mockRunners.getRunnerTeams(kRunnerId)).thenAnswer((_) async => []);
        when(mockRaces.addRaceParticipant(any)).thenAnswer((_) async {});
        when(mockResults.addRaceResult(any)).thenAnswer((_) async {});

        final payload = buildPayload(individualResults: [
          {
            'name': 'Alice',
            'bib_number': '100',
            'grade': 11,
            'place': 1,
          },
        ]);

        await importer.importFromJson(payload);

        verifyNever(mockRunners.createRunner(any));
      });

      test('skips individual result entry with empty name or bib', () async {
        when(mockRaces.createRace(any)).thenAnswer((_) async => kRaceId);

        final payload = buildPayload(individualResults: [
          {'name': '', 'bib_number': '100'},
          {'name': 'Bob', 'bib_number': ''},
        ]);

        final result = await importer.importFromJson(payload);

        expect(result, isA<Success<void>>());
        verifyNever(mockRunners.getRunnerByBib(any));
      });

      test('returns Failure when database throws', () async {
        when(mockRaces.createRace(any)).thenThrow(Exception('db error'));

        final result = await importer.importFromJson(buildPayload());

        expect(result, isA<Failure<void>>());
        final error = (result as Failure).error;
        expect(error.userMessage, contains('Could not import race'));
        expect(error.originalException, isA<Exception>());
      });

      test('returns Failure for invalid JSON', () async {
        final result = await importer.importFromJson('not valid json{{{');

        expect(result, isA<Failure<void>>());
      });
    });
  });
}
