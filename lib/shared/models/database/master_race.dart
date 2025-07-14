import 'package:flutter/material.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import '../../../core/utils/database_helper.dart';
import '../../services/race_results_service.dart';
import 'base_models.dart';

/// Central orchestrator for all race-related data and operations
/// Provides lazy loading, caching, and unified API for race management
class MasterRace with ChangeNotifier {
  static final Map<int, MasterRace> _instances = {};

  final int raceId;

  // Core race data
  Race? _race;
  List<RaceParticipant>? _raceParticipants;
  List<RaceRunner>? _raceRunners;
  List<Team>? _teams;
  List<RaceResult>? _results;

  // Database helper
  final DatabaseHelper db = DatabaseHelper.instance;

  // Participation mapping (cached for performance)
  Map<Team, List<RaceRunner>>? _teamRaceRunnersMap; // team -> [runners]

  Map<Team, List<RaceRunner>>? _filteredSearchResults; // team -> [race runners]

  Map<RaceParticipant, RaceRunner>?
      _raceParticipantToRaceRunnerMap; // race participant -> race runner

  MasterRace._(this.raceId);

  /// Get or create a MasterRace instance for the given race ID
  /// This ensures the same instance is shared across the app
  static MasterRace getInstance(int raceId) {
    return _instances.putIfAbsent(raceId, () => MasterRace._(raceId));
  }

  /// Clear the instance cache (useful for testing or when race is deleted)
  static void clearInstance(int raceId) {
    if (!_instances.containsKey(raceId)) {
      throw Exception('MasterRace instance for race $raceId not found');
    }
    _instances.remove(raceId);
  }

  /// Clear all instances
  static void clearAllInstances() {
    _instances.clear();
  }

  // ============================================================================
  // LAZY LOADING GETTERS
  // ============================================================================

  /// Get race information (lazy loaded)
  Future<Race> get race async {
    if (_race == null) {
      _race = await DatabaseHelper.instance.getRace(raceId);
      if (_race == null) {
        throw Exception('Race with ID $raceId not found');
      }
      notifyListeners();
    }
    return _race!;
  }

  /// Get all runners in the race (lazy loaded)
  Future<List<RaceParticipant>> get raceParticipants async {
    if (_raceParticipants == null) {
      _loadRaceParticipants();
    }
    return _raceParticipants!;
  }

  /// Get all race runners (lazy loaded)
  Future<List<RaceRunner>> get raceRunners async {
    if (_raceRunners == null) {
      _loadRaceRunners();
    }
    return _raceRunners!;
  }

  /// Get all teams in the race (lazy loaded)
  Future<List<Team>> get teams async {
    if (_teams == null) {
      _loadTeams();
    }
    return _teams!;
  }

  /// Get runners grouped by team
  Future<Map<Team, List<RaceRunner>>> get teamtoRaceRunnersMap async {
    if (_teamRaceRunnersMap != null) {
      return _teamRaceRunnersMap!;
    }
    _teamRaceRunnersMap = {};

    final raceRunnersList = await raceRunners;

    for (final raceRunner in raceRunnersList) {
      _teamRaceRunnersMap![raceRunner.team] ??= [];
      _teamRaceRunnersMap![raceRunner.team]!.add(raceRunner);
    }

    return _teamRaceRunnersMap!;
  }

  Future<Map<Team, List<RaceRunner>>> get filteredSearchResults async {
    if (_filteredSearchResults == null) return await teamtoRaceRunnersMap;
    return _filteredSearchResults!;
  }

  /// Get race results (lazy loaded and sorted by place)
  Future<List<RaceResult>> get results async {
    if (_results == null) {
      await _loadResults();
    }
    return _results!;
  }

  Future<RaceRunner?> getRaceRunnerFromRaceParticipant(
      RaceParticipant raceParticipant) async {
    // Check cache first
    if (_raceParticipantToRaceRunnerMap != null &&
        _raceParticipantToRaceRunnerMap!.containsKey(raceParticipant)) {
      return _raceParticipantToRaceRunnerMap![raceParticipant];
    }

    // Initialize cache if needed
    _raceParticipantToRaceRunnerMap ??= {};

    final runner = await db.getRunner(raceParticipant.runnerId!);
    if (runner == null) {
      throw Exception(
          'Runner not found for race participant: ${raceParticipant.runnerId}');
    }
    final team = await db.getTeam(raceParticipant.teamId!);
    if (team == null) {
      throw Exception(
          'Team not found for race participant: ${raceParticipant.teamId}');
    }

    final raceRunner = RaceRunner(
      raceId: raceId,
      runner: runner,
      team: team,
    );

    // Cache the result
    _raceParticipantToRaceRunnerMap![raceParticipant] = raceRunner;

    return raceRunner;
  }

  // ============================================================================
  // DERIVED DATA (COMPUTED FROM CACHED DATA)
  // ============================================================================

  /// Get team standings (sorted by score)
  Future<List<TeamStanding>> get teamStandings async {
    final resultsList = await results;
    final teamsList = await teams;

    return RaceResultsService.calculateTeamStandings(resultsList, teamsList);
  }

  // ============================================================================
  // DATA OPERATIONS
  // ============================================================================

  /// Add a runner to the race
  Future<void> addRaceParticipant(RaceParticipant raceParticipant) async {
    if (raceParticipant.raceId != raceId) {
      throw Exception('Race participant race ID does not match race ID');
    }
    await db.addRaceParticipant(raceParticipant);

    _raceParticipants = null;
    _teamRaceRunnersMap = null;
    _raceParticipantToRaceRunnerMap = null;
    notifyListeners();
  }

  /// Add a new team to this race
  Future<void> addTeamParticipant(TeamParticipant teamParticipant) async {
    if (teamParticipant.raceId != raceId) {
      throw Exception('Team participant race ID does not match race ID');
    }
    await DatabaseHelper.instance.addTeamParticipantToRace(teamParticipant);

    _teams = null;
    _teamRaceRunnersMap = null;
    notifyListeners();
  }

  /// Remove a team from the race
  Future<void> removeTeamFromRace(TeamParticipant teamParticipant) async {
    if (teamParticipant.raceId != raceId) {
      throw Exception('Team participant race ID does not match race ID');
    }
    await DatabaseHelper.instance
        .removeTeamParticipantFromRace(teamParticipant);
    _teams = null;
    _teamRaceRunnersMap = null;
    notifyListeners();
  }

  /// Remove a runner from the race
  Future<void> removeRaceParticipant(RaceParticipant raceParticipant) async {
    if (raceParticipant.raceId != raceId) {
      throw Exception('Race participant race ID does not match race ID');
    }
    await DatabaseHelper.instance.removeRaceParticipant(raceParticipant);
    _raceParticipants = null;
    _teamRaceRunnersMap = null;
    _raceParticipantToRaceRunnerMap = null;
    notifyListeners();
  }

  /// Update race information
  Future<void> updateRace(Race race) async {
    if (race.raceId != raceId) {
      throw Exception('Race ID does not match race ID');
    }
    await DatabaseHelper.instance.updateRace(
      race,
    );

    _race = null;
    notifyListeners();
  }

  Future<void> updateRaceParticipant(RaceParticipant raceParticipant) async {
    await DatabaseHelper.instance.updateRaceParticipant(raceParticipant);
    _raceParticipants = null;
    _teamRaceRunnersMap = null;
    _raceParticipantToRaceRunnerMap = null;
    notifyListeners();
  }

  /// Remove a race runner from the race
  Future<void> removeRaceRunner(RaceRunner raceRunner) async {
    await removeRaceParticipant(RaceParticipant(
      raceId: raceId,
      runnerId: raceRunner.runner.runnerId!,
      teamId: raceRunner.team.teamId!,
    ));
  }

  /// Save race results
  Future<void> saveResults(List<RaceResult> results) async {
    // Convert to database format and save
    final dbResults = results.map((r) => r.toMap()).toList();
    // Note: This would need a proper implementation in DatabaseHelper
    // For now, we'll just invalidate the cache
    _results = null;
    notifyListeners();
  }

  // ============================================================================
  // CONVENIENCE METHODS
  // ============================================================================

  // /// Find a runner by bib number
  // Future<Runner?> getRunnerByBib(String bibNumber) async {
  //   final runnersList = await runners;
  //   try {
  //     return runnersList.firstWhere((r) => r.bibNumber == bibNumber);
  //   } catch (e) {
  //     return null;
  //   }
  // }

  /// Find a team by name
  Future<Team?> getTeamByName(String teamName) async {
    final teamsList = await teams;
    try {
      return teamsList.firstWhere((t) => t.name == teamName);
    } catch (e) {
      return null;
    }
  }

  Future<RaceRunner?> getRaceRunnerByBib(String bibNumber) async {
    final raceRunnersList = await raceRunners;
    return raceRunnersList.firstWhere((r) => r.runner.bibNumber == bibNumber);
  }

  /// Search runners by query (name, bib, team, grade)
  /// Only returns runners whose teams are participating in the race
  Future<void> searchRaceRunners(String query,
      [String searchAttribute = 'all']) async {
    Future<void> sortSearchResults() async {
      // Sort the race runners for every team in parallel
      await Future.wait(
        _filteredSearchResults!.values.map((raceRunners) async {
          raceRunners.sort((a, b) {
            final aName = a.runner.name ?? '';
            final bName = b.runner.name ?? '';
            return aName.compareTo(bName);
          });
        }),
      );
    }
    if (query.isEmpty) {
      _filteredSearchResults = await teamtoRaceRunnersMap;
      await sortSearchResults();
      notifyListeners();
      return;
    }
    final raceRunnersList = await raceRunners; // All runners

    final lowerQuery = query.toLowerCase();

    // Process all participants in parallel, using cache when available
    final results = await Future.wait(
      raceRunnersList.map((raceRunner) async {
        final runner = raceRunner.runner;
        if (searchAttribute == 'all') {
          final matchesName = runner.name!.toLowerCase().contains(lowerQuery);
          final matchesBib =
              runner.bibNumber!.toLowerCase().contains(lowerQuery);
          final matchesGrade = runner.grade!.toString().contains(lowerQuery);

          // Find team name for this runner
          bool matchesTeam = false;
          try {
            matchesTeam =
                raceRunner.team.name?.toLowerCase().contains(lowerQuery) ??
                    false;
          } catch (e) {
            // Team not found, continue
          }

          if (matchesName || matchesBib || matchesGrade || matchesTeam) {
            return raceRunner;
          }
        } else {
          switch (searchAttribute) {
            case 'name':
              if (runner.name!.toLowerCase().contains(lowerQuery)) {
                return raceRunner;
              }
              break;
            case 'bib':
              if (runner.bibNumber!.toLowerCase().contains(lowerQuery)) {
                return raceRunner;
              }
              break;
            case 'grade':
              if (runner.grade!.toString().contains(lowerQuery)) {
                return raceRunner;
              }
              break;
          }
        }
        return null;
      }),
    );

    final filteredRaceRunners = results.whereType<RaceRunner>().toList();
    final filteredTeamRaceRunnersMap = <Team, List<RaceRunner>>{};
    for (final raceRunner in filteredRaceRunners) {
      filteredTeamRaceRunnersMap[raceRunner.team] ??= [];
      filteredTeamRaceRunnersMap[raceRunner.team]!.add(raceRunner);
    }
    _filteredSearchResults = filteredTeamRaceRunnersMap;
    await sortSearchResults();
    notifyListeners();
  }

  /// Get all available teams (from other races) that could be added to this race
  Future<List<Team>> getOtherTeams() async {
    final allTeams = await DatabaseHelper.instance.getAllTeams();
    final currentTeams = await teams;
    final currentTeamIds = currentTeams.map((t) => t.teamId).toSet();

    return allTeams
        .map((teamData) => Team.fromMap(teamData.toMap()))
        .where((team) => !currentTeamIds.contains(team.teamId))
        .toList();
  }

  // ============================================================================
  // CACHE MANAGEMENT
  // ============================================================================

  /// Invalidate all cached data
  void invalidateCache() {
    _race = null;
    _raceParticipants = null;
    _teams = null;
    _results = null;
    _teamRaceRunnersMap = null;
    _raceParticipantToRaceRunnerMap = null;
    notifyListeners();
  }

  // ============================================================================
  // PRIVATE LOADING METHODS
  // ============================================================================

  Future<void> _loadRaceParticipants() async {
    _raceParticipants =
        await DatabaseHelper.instance.getRaceParticipants(raceId);
    notifyListeners();
  }

  Future<void> _loadRaceRunners() async {
    final participants = await raceParticipants;
    _raceRunners = await Future.wait(participants.map((participant) async {
      final raceRunner = await getRaceRunnerFromRaceParticipant(participant);
      if (raceRunner == null) {
        throw Exception(
            'Runner not found for race participant: ${participant.runnerId}');
      }
      return raceRunner;
    }));
    notifyListeners();
  }

  Future<void> _loadTeams() async {
    _teams = await DatabaseHelper.instance.getRaceTeams(raceId);
    notifyListeners();
  }

  Future<void> _loadResults() async {
    final resultsData = await DatabaseHelper.instance.getRaceResults(raceId);
    _results =
        resultsData.map((data) => RaceResult.fromMap(data.toMap())).toList();
    notifyListeners();
  }
}

/// Represents team standings in a race
class TeamStanding {
  final Team team;
  final int score;
  final int? place;
  final List<RaceResult> scoringRunners;
  final List<RaceResult> allRunners;
  final Duration? split; // Time difference between 1st and 5th scorer

  const TeamStanding({
    required this.team,
    required this.score,
    this.place,
    required this.scoringRunners,
    required this.allRunners,
    this.split,
  });

  TeamStanding copyWith({
    Team? team,
    int? score,
    int? place,
    List<RaceResult>? scoringRunners,
    List<RaceResult>? allRunners,
    Duration? split,
  }) {
    return TeamStanding(
      team: team ?? this.team,
      score: score ?? this.score,
      place: place ?? this.place,
      scoringRunners: scoringRunners ?? this.scoringRunners,
      allRunners: allRunners ?? this.allRunners,
      split: split ?? this.split,
    );
  }
}
