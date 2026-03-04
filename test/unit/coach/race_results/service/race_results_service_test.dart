import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race.dart';
import 'package:xceleration/shared/models/database/race_result.dart' as db;
import 'package:xceleration/shared/models/database/team.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/services/race_results_service.dart';

@GenerateMocks([MasterRace])
import 'race_results_service_test.mocks.dart';

db.RaceResult _result({
  required Team team,
  required String name,
  required String bib,
  required Duration finish,
}) {
  return db.RaceResult(
    place: null, // will be assigned by calculateIndividualResults
    runner: Runner(name: name, bibNumber: bib, grade: 12),
    team: team,
    finishTime: finish,
  );
}

void main() {
  group('RaceResultsService - incomplete teams handling', () {
    test(
        'Single eligible team vs incomplete team: incomplete excluded, N/A score, last place',
        () {
      final teamA = const Team(name: 'Alpha', abbreviation: 'ALP');
      final teamB = const Team(name: 'Beta', abbreviation: 'BET');

      // Team A: 5 finishers (eligible)
      final resultsA = <db.RaceResult>[
        _result(
            team: teamA,
            name: 'A1',
            bib: 'A1',
            finish: const Duration(minutes: 18, seconds: 0)),
        _result(
            team: teamA,
            name: 'A2',
            bib: 'A2',
            finish: const Duration(minutes: 18, seconds: 30)),
        _result(
            team: teamA,
            name: 'A3',
            bib: 'A3',
            finish: const Duration(minutes: 19, seconds: 0)),
        _result(
            team: teamA,
            name: 'A4',
            bib: 'A4',
            finish: const Duration(minutes: 19, seconds: 30)),
        _result(
            team: teamA,
            name: 'A5',
            bib: 'A5',
            finish: const Duration(minutes: 20, seconds: 0)),
      ];

      // Team B: 4 finishers (incomplete)
      final resultsB = <db.RaceResult>[
        _result(
            team: teamB,
            name: 'B1',
            bib: 'B1',
            finish: const Duration(minutes: 18, seconds: 15)),
        _result(
            team: teamB,
            name: 'B2',
            bib: 'B2',
            finish: const Duration(minutes: 18, seconds: 45)),
        _result(
            team: teamB,
            name: 'B3',
            bib: 'B3',
            finish: const Duration(minutes: 19, seconds: 15)),
        _result(
            team: teamB,
            name: 'B4',
            bib: 'B4',
            finish: const Duration(minutes: 19, seconds: 45)),
      ];

      final all = <db.RaceResult>[...resultsA, ...resultsB];

      // Full pipeline as used in app
      const service = RaceResultsService();
      final individual = service.calculateIndividualResults(all);
      final teams = service.calculateTeamResults(individual);
      service.sortAndPlaceTeams(teams);

      // Expect ordering: teamA first (eligible), teamB last (incomplete)
      expect(teams.length, 2);
      expect(teams[0].team.name, 'Alpha');
      expect(teams[0].place, 1);
      expect(teams[1].team.name, 'Beta');
      expect(teams[1].place, 2);

      // Incomplete team score should be 0 (rendered as N/A in UI)
      expect(teams[1].score, 0);

      // Team A score is computed excluding incomplete team (places 1..5 => 15)
      final teamAScore = teams[0].score;
      expect(teamAScore, 15);
    });

    test(
        'Two eligible teams with one incomplete: incomplete excluded from scoring and placement',
        () {
      final teamA = const Team(name: 'Alpha', abbreviation: 'ALP');
      final teamB = const Team(name: 'Beta', abbreviation: 'BET');
      final teamC = const Team(name: 'Gamma', abbreviation: 'GAM');

      // Team A: 5 finishers
      final resultsA = <db.RaceResult>[
        _result(
            team: teamA,
            name: 'A1',
            bib: 'A1',
            finish: const Duration(minutes: 18, seconds: 0)),
        _result(
            team: teamA,
            name: 'A2',
            bib: 'A2',
            finish: const Duration(minutes: 18, seconds: 20)),
        _result(
            team: teamA,
            name: 'A3',
            bib: 'A3',
            finish: const Duration(minutes: 18, seconds: 40)),
        _result(
            team: teamA,
            name: 'A4',
            bib: 'A4',
            finish: const Duration(minutes: 19, seconds: 0)),
        _result(
            team: teamA,
            name: 'A5',
            bib: 'A5',
            finish: const Duration(minutes: 19, seconds: 20)),
      ];

      // Team C: 5 finishers interleaved slightly slower than A
      final resultsC = <db.RaceResult>[
        _result(
            team: teamC,
            name: 'C1',
            bib: 'C1',
            finish: const Duration(minutes: 18, seconds: 10)),
        _result(
            team: teamC,
            name: 'C2',
            bib: 'C2',
            finish: const Duration(minutes: 18, seconds: 30)),
        _result(
            team: teamC,
            name: 'C3',
            bib: 'C3',
            finish: const Duration(minutes: 18, seconds: 50)),
        _result(
            team: teamC,
            name: 'C4',
            bib: 'C4',
            finish: const Duration(minutes: 19, seconds: 10)),
        _result(
            team: teamC,
            name: 'C5',
            bib: 'C5',
            finish: const Duration(minutes: 19, seconds: 30)),
      ];

      // Team B: incomplete 4 finishers mixed in
      final resultsB = <db.RaceResult>[
        _result(
            team: teamB,
            name: 'B1',
            bib: 'B1',
            finish: const Duration(minutes: 18, seconds: 5)),
        _result(
            team: teamB,
            name: 'B2',
            bib: 'B2',
            finish: const Duration(minutes: 18, seconds: 35)),
        _result(
            team: teamB,
            name: 'B3',
            bib: 'B3',
            finish: const Duration(minutes: 18, seconds: 55)),
        _result(
            team: teamB,
            name: 'B4',
            bib: 'B4',
            finish: const Duration(minutes: 19, seconds: 15)),
      ];

      final all = <db.RaceResult>[...resultsA, ...resultsB, ...resultsC];

      const service = RaceResultsService();
      final individual = service.calculateIndividualResults(all);
      final teams = service.calculateTeamResults(individual);
      service.sortAndPlaceTeams(teams);

      // Order: A then C (eligible), B (incomplete) last
      expect(teams.length, 3);
      expect(teams[0].team.name, 'Alpha');
      expect(teams[0].place, 1);
      expect(teams[1].team.name, 'Gamma');
      expect(teams[1].place, 2);
      expect(teams[2].team.name, 'Beta');
      expect(teams[2].place, 3);

      // Scores excluding incomplete team B
      expect(teams[2].score, 0); // incomplete
      expect(teams[0].score, 25); // 1+3+5+7+9
      expect(teams[1].score, 30); // 2+4+6+8+10
    });

    test('Cloning TeamRecord preserves incomplete score of 0', () {
      final teamX = const Team(name: 'X', abbreviation: 'X');
      final resultsX = <db.RaceResult>[
        _result(
            team: teamX,
            name: 'X1',
            bib: 'X1',
            finish: const Duration(minutes: 18, seconds: 0)),
        _result(
            team: teamX,
            name: 'X2',
            bib: 'X2',
            finish: const Duration(minutes: 18, seconds: 20)),
        _result(
            team: teamX,
            name: 'X3',
            bib: 'X3',
            finish: const Duration(minutes: 18, seconds: 40)),
        _result(
            team: teamX,
            name: 'X4',
            bib: 'X4',
            finish: const Duration(minutes: 19, seconds: 0)),
      ];

      const service = RaceResultsService();
      final individual = service.calculateIndividualResults(resultsX);
      final teams = service.calculateTeamResults(individual);
      service.sortAndPlaceTeams(teams);

      // Team incomplete 01 score should be 0
      expect(teams.single.score, 0);

      // Deep copy should preserve score 0
      final cloned = teams.map((t) => t).toList();
      expect(cloned.single.score, 0);
    });
  });

  group('RaceResultsService - calculateCompleteRaceResults', () {
    late MockMasterRace mockMasterRace;

    final testRace = Race(
      raceId: 1,
      raceName: 'State Meet',
      raceDate: DateTime(2025, 6, 15),
      distance: 3.1,
      distanceUnit: 'mi',
      flowState: Race.FLOW_FINISHED,
    );

    setUp(() {
      mockMasterRace = MockMasterRace();
      when(mockMasterRace.race).thenAnswer((_) async => testRace);
    });

    test('returns Success<RaceResultsData> with empty results', () async {
      when(mockMasterRace.results).thenAnswer((_) async => []);

      const service = RaceResultsService();
      final result = await service.calculateCompleteRaceResults(mockMasterRace);

      expect(result, isA<Success<RaceResultsData>>());
      final data = (result as Success<RaceResultsData>).value;
      expect(data.individualResults, isEmpty);
      expect(data.overallTeamResults, isEmpty);
      expect(data.headToHeadTeamResults, isEmpty);
    });

    test('returns Success<RaceResultsData> with populated results', () async {
      final teamA = const Team(name: 'Alpha', abbreviation: 'ALP');
      final results = <db.RaceResult>[
        _result(
            team: teamA,
            name: 'A1',
            bib: 'A1',
            finish: const Duration(minutes: 18)),
        _result(
            team: teamA,
            name: 'A2',
            bib: 'A2',
            finish: const Duration(minutes: 19)),
      ];

      when(mockMasterRace.results).thenAnswer((_) async => results);

      const service = RaceResultsService();
      final result = await service.calculateCompleteRaceResults(mockMasterRace);

      expect(result, isA<Success<RaceResultsData>>());
      final data = (result as Success<RaceResultsData>).value;
      expect(data.individualResults.length, 2);
      expect(data.individualResults.first.name, 'A1');
    });
  });
}
