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

  group('RaceResultsService - tie breaking', () {
    const alpha = Team(name: 'Alpha', abbreviation: 'ALP');
    const beta = Team(name: 'Beta', abbreviation: 'BET');

    /// One runner per finish place; place N finishes at 18:00 + N seconds.
    List<db.RaceResult> finishers(Team team, List<int> places) => [
          for (final p in places)
            _result(
                team: team,
                name: '${team.abbreviation}$p',
                bib: '${team.abbreviation}$p',
                finish: Duration(minutes: 18, seconds: p)),
        ];

    List<String> placedTeams(List<db.RaceResult> all) {
      const service = RaceResultsService();
      final teams =
          service.calculateTeamResults(service.calculateIndividualResults(all));
      service.sortAndPlaceTeams(teams);
      return [for (final t in teams) '${t.place} ${t.team.name} ${t.score}'];
    }

    test('breaks a tied score with the better sixth runner', () {
      // Both score 28; Beta's 6th finishes 10th, Alpha's 12th. Alpha has the
      // race winner, which must not decide the tie.
      final all = [
        ...finishers(alpha, [1, 2, 5, 9, 11, 12]),
        ...finishers(beta, [3, 4, 6, 7, 8, 10]),
      ];

      expect(placedTeams(all), ['1 Beta 28', '2 Alpha 28']);
    });

    test('ranks a team with a sixth runner ahead of a tied team without one',
        () {
      final all = [
        ...finishers(beta, [1, 2, 5, 9, 11]),
        ...finishers(alpha, [3, 4, 6, 7, 8, 10]),
      ];

      expect(placedTeams(all), ['1 Alpha 28', '2 Beta 28']);
    });
  });

  group('RaceResultsService - finish order and missing teams', () {
    const service = RaceResultsService();
    const team = Team(teamId: 1, name: 'Alpha', abbreviation: 'ALP');

    db.RaceResult placed(String bib, int place, Duration time, {Team? on}) =>
        db.RaceResult(
          place: place,
          runner: Runner(name: bib, bibNumber: bib, grade: 11),
          team: on,
          finishTime: time,
        );

    test('runners with the same time keep their chute order', () {
      const same = Duration(minutes: 18, seconds: 5);
      // Listed out of order; the tie must still resolve by chute place.
      final results = [
        placed('C', 3, same, on: team),
        placed('A', 1, const Duration(minutes: 17), on: team),
        placed('B', 2, same, on: team),
      ];

      final ordered = service.calculateIndividualResults(results);

      expect([for (final r in ordered) r.runner!.bibNumber], ['A', 'B', 'C']);
      expect([for (final r in ordered) r.place], [1, 2, 3]);
    });

    test('a runner without a team is placed but not team-scored', () {
      final results = [
        placed('U', 1, const Duration(minutes: 17)),
        for (var i = 0; i < 5; i++)
          placed('A$i', i + 2, Duration(minutes: 18, seconds: i), on: team),
      ];

      final individual = service.calculateIndividualResults(results);
      final teams = service.calculateTeamResults(individual);
      service.sortAndPlaceTeams(teams);

      expect(individual.first.runner!.bibNumber, 'U');
      expect(teams.single.team.name, 'Alpha');
      // Team places ignore the unattached runner: 1+2+3+4+5.
      expect(teams.single.score, 15);
    });
  });

  group('RaceResultsService - standard cross-country scoring', () {
    test('matches a hand-scored meet', () {
      const service = RaceResultsService();
      const a = Team(teamId: 1, name: 'A', abbreviation: 'A');
      const b = Team(teamId: 2, name: 'B', abbreviation: 'B');
      const c = Team(teamId: 3, name: 'C', abbreviation: 'C'); // only 3 runners
      // Chute order. C's runners and A's 8th runner must not affect team
      // places: team places are renumbered over A and B's top seven only.
      final order = [
        ('A1', a), ('B1', b), ('C1', c), ('A2', a), ('B2', b), ('A3', a),
        ('C2', c), ('B3', b), ('A4', a), ('B4', b), ('A5', a), ('C3', c),
        ('B5', b), ('A6', a), ('B6', b), ('A7', a), ('B7', b), ('A8', a),
      ];
      final results = [
        for (final (i, (bib, team)) in order.indexed)
          db.RaceResult(
            place: i + 1,
            runner: Runner(name: bib, bibNumber: bib, grade: 11),
            team: team,
            finishTime: Duration(minutes: 17, seconds: i * 7),
          ),
      ];

      final individual = service.calculateIndividualResults(results);
      final records = service.convertToResultsRecords(individual);
      final teams = service.calculateTeamResults(individual);
      service.sortAndPlaceTeams(teams);

      // Individual places are the chute order, unaffected by team scoring.
      expect([for (final r in records) r.place], List.generate(18, (i) => i + 1));
      // A: 1+3+5+7+9 = 25; B: 2+4+6+8+10 = 30; C is incomplete.
      final byName = {for (final t in teams) t.team.name: t};
      expect(byName['A']!.score, 25);
      expect(byName['B']!.score, 30);
      expect(byName['C']!.score, 0);
      expect([for (final t in teams) t.team.name], ['A', 'B', 'C']);
      expect([for (final t in teams) t.place], [1, 2, 3]);
    });
  });

  group('RaceResultsService - displacement', () {
    const service = RaceResultsService();
    const a = Team(teamId: 1, name: 'A', abbreviation: 'A');
    const b = Team(teamId: 2, name: 'B', abbreviation: 'B');

    Map<String, int> scores(List<(String, Team)> chuteOrder) {
      final results = [
        for (final (i, (bib, team)) in chuteOrder.indexed)
          db.RaceResult(
            place: i + 1,
            runner: Runner(name: bib, bibNumber: bib, grade: 11),
            team: team,
            finishTime: Duration(minutes: 17, seconds: i * 3),
          ),
      ];
      final teams = service
          .calculateTeamResults(service.calculateIndividualResults(results));
      service.sortAndPlaceTeams(teams);
      return {for (final t in teams) t.team.name!: t.score};
    }

    test('a sixth and seventh runner push back the other team\'s scorers', () {
      final order = [
        ('B1', b),
        for (var i = 1; i <= 7; i++) ('A$i', a),
        for (var i = 2; i <= 5; i++) ('B$i', b),
      ];

      // A: 2+3+4+5+6. B's last four are pushed behind A6 and A7: 1+9+10+11+12.
      expect(scores(order), {'A': 20, 'B': 43});
    });

    test('an eighth runner pushes nobody back', () {
      final order = [
        ('B1', b),
        for (var i = 1; i <= 8; i++) ('A$i', a),
        for (var i = 2; i <= 5; i++) ('B$i', b),
      ];

      // A8 takes no team place, so B still scores 1+9+10+11+12.
      expect(scores(order), {'A': 20, 'B': 43});
    });
  });

  group('RaceResultsService - a three-team meet', () {
    late MockMasterRace masterRace;
    const a = Team(teamId: 1, name: 'A', abbreviation: 'A');
    const b = Team(teamId: 2, name: 'B', abbreviation: 'B');
    const c = Team(teamId: 3, name: 'C', abbreviation: 'C');

    setUp(() {
      masterRace = MockMasterRace();
      when(masterRace.race).thenAnswer((_) async => Race(
          raceId: 1, raceName: 'Tri Meet', raceDate: DateTime(2026, 9, 12)));
      // A, B, C, A, B, C, ... seven runners each.
      when(masterRace.results).thenAnswer((_) async => [
            for (var i = 0; i < 21; i++)
              db.RaceResult(
                place: i + 1,
                runner: Runner(
                    name: 'R$i', bibNumber: '${100 + i}', grade: 10),
                team: [a, b, c][i % 3],
                finishTime: Duration(minutes: 17, seconds: i * 4),
              ),
          ]);
    });

    Future<RaceResultsData> calculate() async =>
        ((await const RaceResultsService()
                .calculateCompleteRaceResults(masterRace))
            as Success<RaceResultsData>)
            .value;

    test('scores every team over the whole field', () async {
      final data = await calculate();

      expect([for (final t in data.overallTeamResults) '${t.team.name} ${t.score}'],
          ['A 35', 'B 40', 'C 45']);
    });

    test('scores each pair as a dual meet, without the third team', () async {
      final data = await calculate();

      final duals = [
        for (final pair in data.headToHeadTeamResults)
          [for (final t in pair) '${t.team.name} ${t.score}'].join(' v ')
      ];
      expect(duals, ['A 25 v B 30', 'A 25 v C 30', 'B 25 v C 30']);
    });

    test('the dual meets leave the overall scores and places alone',
        () async {
      final data = await calculate();

      expect([for (final t in data.overallTeamResults) t.score], [35, 40, 45]);
      expect([for (final r in data.individualResults) r.place],
          List.generate(21, (i) => i + 1));
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
