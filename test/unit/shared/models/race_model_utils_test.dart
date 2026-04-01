import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/merge_conflicts/controller/merge_conflicts_controller.dart';
import 'package:xceleration/coach/merge_conflicts/utils/timing_data_converter.dart'
    show CoachTimingDataConverter;
import 'package:xceleration/coach/share_race/services/race_share_service.dart';
import 'package:xceleration/core/repositories/i_race_repository.dart';
import 'package:xceleration/core/repositories/i_results_repository.dart';
import 'package:xceleration/core/repositories/i_runner_repository.dart';
import 'package:xceleration/core/repositories/i_team_repository.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/service_locator.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/utils/race_share_decoder.dart';
import 'package:xceleration/shared/models/database/base_models.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

@GenerateMocks([
  IRaceRepository,
  IRunnerRepository,
  ITeamRepository,
  IResultsRepository,
])
import 'race_model_utils_test.mocks.dart';

MergeConflictsController _makeController({
  required List<TimingDatum> timingData,
  required TimingDatum conflictRecord,
  required List<RaceRunner> runners,
  int chunkId = 0,
}) {
  final chunk = TimingChunk(
    id: chunkId,
    timingData: timingData,
    conflictRecord: conflictRecord,
  );
  return MergeConflictsController(
    masterRace: MasterRace.getInstance(chunkId),
    timingChunks: [chunk],
    raceRunners: runners,
  );
}

void main() {
  // ===========================================================================
  // MergeConflictsController.insertTbdAt
  // ===========================================================================
  group('MergeConflictsController.insertTbdAt', () {
    late List<RaceRunner> testRunners;

    setUp(() {
      testRunners = List.generate(
          10,
          (i) => RaceRunner(
                raceId: 1,
                runner: Runner(
                  runnerId: i + 1,
                  name: 'Runner ${i + 1}',
                  grade: 10,
                  bibNumber: (i + 1).toString(),
                ),
                team: Team(
                  teamId: 1,
                  name: 'Team',
                  abbreviation: 'T',
                ),
              ));
    });

    test('inserts TBD and removes first TBD when clicking on actual time', () {
      final timingData =
          ['1.0', '2.0', '4.0'].map((time) => TimingDatum(time: time)).toList();
      final conflictRecord = TimingDatum(
        time: '4.0',
        conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
      );

      final controller = _makeController(
        timingData: timingData,
        conflictRecord: conflictRecord,
        runners: testRunners,
      );

      controller.insertTbdAt(0, 1);

      expect(controller.uiChunks.first.times,
          equals(['1.0', 'TBD', '2.0', '4.0']));
    });

    test('handles multiple TBD entries correctly', () {
      final timingData =
          ['1.0', '3.0', '5.0'].map((time) => TimingDatum(time: time)).toList();
      final conflictRecord = TimingDatum(
        time: '5.0',
        conflict: Conflict(type: ConflictType.missingTime, offBy: 2),
      );

      final controller = _makeController(
        timingData: timingData,
        conflictRecord: conflictRecord,
        runners: testRunners,
        chunkId: 1,
      );

      controller.insertTbdAt(1, 1);

      expect(controller.uiChunks.first.times,
          equals(['1.0', 'TBD', '3.0', '5.0', 'TBD']));
    });

    test('handles case where clicking on first time entry', () {
      final timingData =
          ['1.0', '2.0', '3.0'].map((time) => TimingDatum(time: time)).toList();
      final conflictRecord = TimingDatum(
        time: '3.0',
        conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
      );

      final controller = _makeController(
        timingData: timingData,
        conflictRecord: conflictRecord,
        runners: testRunners,
        chunkId: 2,
      );

      controller.insertTbdAt(2, 0);

      expect(controller.uiChunks.first.times,
          equals(['TBD', '1.0', '2.0', '3.0']));
    });

    test('works with offBy > 1', () {
      final timingData = ['1.0', '2.0', '4.0', '6.0']
          .map((time) => TimingDatum(time: time))
          .toList();
      final conflictRecord = TimingDatum(
        time: '6.0',
        conflict: Conflict(type: ConflictType.missingTime, offBy: 2),
      );

      final controller = _makeController(
        timingData: timingData,
        conflictRecord: conflictRecord,
        runners: testRunners,
        chunkId: 3,
      );

      controller.insertTbdAt(3, 1);

      expect(controller.uiChunks.first.times,
          equals(['1.0', 'TBD', '2.0', '4.0', '6.0', 'TBD']));
    });

    test('handles edge case where conflict is confirmRunner', () {
      final timingData = ['1.0', '2.0', '3.0', '4.0']
          .map((time) => TimingDatum(time: time))
          .toList();
      final conflictRecord = TimingDatum(
        time: '4.0',
        conflict: Conflict(type: ConflictType.confirmRunner, offBy: 0),
      );

      final controller = _makeController(
        timingData: timingData,
        conflictRecord: conflictRecord,
        runners: testRunners,
        chunkId: 4,
      );

      controller.insertTbdAt(4, 1);

      expect(controller.uiChunks.first.times,
          equals(['1.0', 'TBD', '2.0', '3.0', '4.0']));
    });
  });

  // ===========================================================================
  // UIChunk.convertToUIChunks
  // ===========================================================================
  group('UIChunk.convertToUIChunks', () {
    test('converts timing chunks to UI chunks correctly', () {
      final runners = List.generate(
          3,
          (i) => RaceRunner(
                raceId: 1,
                runner: Runner(
                  runnerId: i + 1,
                  name: 'Runner ${i + 1}',
                  grade: 10,
                  bibNumber: (i + 1).toString(),
                ),
                team: Team(teamId: 1, name: 'Team', abbreviation: 'T'),
              ));

      final timingChunks = [
        TimingChunk(
          id: 10,
          timingData: ['1.0', '2.0'].map((t) => TimingDatum(time: t)).toList(),
          conflictRecord: TimingDatum(
            time: '2.0',
            conflict: Conflict(type: ConflictType.confirmRunner, offBy: 0),
          ),
        ),
      ];

      final uiChunks =
          CoachTimingDataConverter.convertToUIChunks(timingChunks, runners);

      expect(uiChunks.length, equals(1));
      expect(uiChunks.first.chunkId, equals(10));
      expect(uiChunks.first.times, equals(['1.0', '2.0']));
    });
  });

  // ===========================================================================
  // Race share encode/decode
  // ===========================================================================
  group('Race share encode/decode', () {
    test('preparePayloadFromData produces compact base64+gzip V2 payload', () {
      final race = Race(
        uuid: 'r-uuid',
        raceName: 'Test Meet',
        raceDate: DateTime.utc(2025, 9, 23),
        location: 'Somewhere',
        distance: 5.0,
        distanceUnit: 'mi',
        flowState: Race.FLOW_FINISHED,
      );

      final team = Team(name: 'Wildcats', abbreviation: 'WIL');
      final results = <RaceResult>[
        RaceResult(
          place: 1,
          runner: Runner(name: 'Alice', bibNumber: '100', grade: 12),
          team: team,
          finishTime: const Duration(minutes: 18, seconds: 5, milliseconds: 30),
        ),
        RaceResult(
          place: 2,
          runner: Runner(name: 'Bob', bibNumber: '101', grade: 12),
          team: team,
          finishTime:
              const Duration(minutes: 18, seconds: 45, milliseconds: 10),
        ),
      ];

      final encoded = RaceShareService.preparePayloadFromData(
        race: race,
        results: results,
      );
      final decodedJson = utf8.decode(gzip.decode(base64Decode(encoded)));
      final map = jsonDecode(decodedJson) as Map<String, dynamic>;
      expect(map['type'], 'RACE_SHARE_V2');
      expect(map['race']['name'], 'Test Meet');
      expect((map['r'] as List).length, 2);
      expect(map['r'][0][0], 1);
      expect(map['r'][0][1], 'Alice');
      expect(map['r'][0][3], 18 * 60 * 1000 + 5 * 1000 + 30);
    });

    test('decodeToResultsData returns Success with reconstructed data', () {
      final race = Race(
        uuid: 'r-uuid',
        raceName: 'Preview Race',
        raceDate: DateTime.utc(2025, 9, 23),
        location: 'Park',
        distance: 5.0,
        distanceUnit: 'mi',
        flowState: Race.FLOW_FINISHED,
      );
      final team = Team(name: 'Hawks', abbreviation: 'HAW');
      final results = <RaceResult>[
        RaceResult(
          place: 1,
          runner: Runner(name: 'Eve', bibNumber: '200', grade: 11),
          team: team,
          finishTime: const Duration(minutes: 19, seconds: 10),
        ),
        RaceResult(
          place: 2,
          runner: Runner(name: 'Dan', bibNumber: '201', grade: 10),
          team: team,
          finishTime: const Duration(minutes: 19, seconds: 50),
        ),
      ];

      final payload = RaceShareService.preparePayloadFromData(
        race: race,
        results: results,
      );

      final result = RaceShareDecoder.decodeToResultsData(payload);
      expect(result, isA<Success<RaceShareDecodedData>>());
      final decoded = (result as Success<RaceShareDecodedData>).value;
      expect(decoded.title.contains('Preview Race'), isTrue);
      expect(decoded.results.individualResults.length, 2);
      expect(decoded.results.individualResults.first.name, 'Eve');
      expect(decoded.results.overallTeamResults.isNotEmpty, isTrue);
    });

    test('decodeToResultsData returns Failure for invalid payload', () {
      final result =
          RaceShareDecoder.decodeToResultsData('not-valid-base64!!!');
      expect(result, isA<Failure<RaceShareDecodedData>>());
      final error = (result as Failure<RaceShareDecodedData>).error;
      expect(error.userMessage, isNotEmpty);
      expect(error.originalException, isNotNull);
    });

    test('decodeToResultsData returns Failure for unsupported payload type',
        () {
      final json = jsonEncode({'type': 'RACE_SHARE_V1', 'race': {}, 'r': []});
      final encoded = base64Encode(gzip.encode(utf8.encode(json)));

      final result = RaceShareDecoder.decodeToResultsData(encoded);
      expect(result, isA<Failure<RaceShareDecodedData>>());
    });

    test('decodeWithRaw returns Success with rawEncoded preserved', () {
      final race = Race(
        uuid: 'r-uuid',
        raceName: 'Test Race',
        raceDate: DateTime.utc(2025, 9, 23),
        location: 'Track',
        distance: 5.0,
        distanceUnit: 'mi',
        flowState: Race.FLOW_FINISHED,
      );
      final team = Team(name: 'Tigers', abbreviation: 'TIG');
      final raceResults = <RaceResult>[
        RaceResult(
          place: 1,
          runner: Runner(name: 'Sam', bibNumber: '300', grade: 11),
          team: team,
          finishTime: const Duration(minutes: 20, seconds: 0),
        ),
      ];

      final payload = RaceShareService.preparePayloadFromData(
        race: race,
        results: raceResults,
      );

      final result = RaceShareDecoder.decodeWithRaw(payload);
      expect(result, isA<Success>());
      final value = (result as Success).value;
      expect(value.rawEncoded, equals(payload));
      expect(value.results.individualResults.length, 1);
    });

    test('decodeWithRaw returns Failure for invalid payload', () {
      final result = RaceShareDecoder.decodeWithRaw('garbage');
      expect(result, isA<Failure>());
      final error = (result as Failure).error;
      expect(error.userMessage, isNotEmpty);
    });

    test('encode/decode 75 runners and print lengths', () {
      final race = Race(
        uuid: 'r-uuid-75',
        raceName: 'Big Race',
        raceDate: DateTime.utc(2025, 9, 23),
        location: 'XC Course',
        distance: 5.0,
        distanceUnit: 'mi',
        flowState: Race.FLOW_FINISHED,
      );

      final teams = [
        Team(name: 'Hawks', abbreviation: 'HAW'),
        Team(name: 'Wolves', abbreviation: 'WOL'),
        Team(name: 'Bears', abbreviation: 'BEA'),
      ];

      final List<RaceResult> results = [];
      for (int i = 0; i < 75; i++) {
        final team = teams[i % teams.length];
        results.add(RaceResult(
          place: i + 1,
          runner: Runner(
              name: 'Runner ${i + 1}',
              bibNumber: 'B${i + 1}',
              grade: 9 + (i % 4)),
          team: team,
          finishTime: Duration(minutes: 18 + (i ~/ 10), seconds: (i * 3) % 60),
        ));
      }

      final encoded = RaceShareService.preparePayloadFromData(
        race: race,
        results: results,
      );

      final result = RaceShareDecoder.decodeToResultsData(encoded);
      expect(result, isA<Success<RaceShareDecodedData>>());
      final decoded = (result as Success<RaceShareDecodedData>).value;
      expect(decoded.results.individualResults.length, 75);

      final compressedLen = encoded.length;
      final plainJsonLen =
          utf8.decode(gzip.decode(base64Decode(encoded))).length;
      Logger.d(
          'RaceShare lengths — compressed(base64): $compressedLen chars, json: $plainJsonLen chars');
    });
  });

  // ===========================================================================
  // MasterRace
  // ===========================================================================
  group('MasterRace', () {
    late MockIRaceRepository mockRaceRepo;
    late MockIRunnerRepository mockRunnerRepo;
    late MockITeamRepository mockTeamRepo;
    late MockIResultsRepository mockResultsRepo;

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

        await masterRace.searchRaceRunners('Bob');

        final filtered = await masterRace.filteredSearchResults;
        expect(filtered.values.expand((v) => v), isEmpty);
      });

      test('returns all runners after an empty query resets the filter', () async {
        final masterRace = MasterRace.getInstance(raceId);

        await masterRace.searchRaceRunners('Bob');
        await masterRace.searchRaceRunners('');

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
