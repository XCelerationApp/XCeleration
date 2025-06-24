import 'package:flutter/material.dart';
import 'dart:convert';

/// Consolidated race model with all race-related data and business logic
class RaceModel {
  final int raceId;
  final String raceName;
  final DateTime? raceDate;
  final String location;
  final double distance;
  final String distanceUnit;
  final List<Color> teamColors;
  final List<String> teams;
  final String flowState;
  final List<RunnerModel> runners;
  final RaceStatistics statistics;

  // Flow state constants
  static const String FLOW_SETUP = 'setup';
  static const String FLOW_SETUP_COMPLETED = 'setup-completed';
  static const String FLOW_PRE_RACE = 'pre-race';
  static const String FLOW_PRE_RACE_COMPLETED = 'pre-race-completed';
  static const String FLOW_POST_RACE = 'post-race';
  static const String FLOW_POST_RACE_COMPLETED = 'post-race-completed';
  static const String FLOW_FINISHED = 'finished';
  static const String FLOW_COMPLETED_SUFFIX = '-completed';

  const RaceModel({
    required this.raceId,
    required this.raceName,
    this.raceDate,
    required this.location,
    required this.distance,
    required this.distanceUnit,
    required this.teamColors,
    required this.teams,
    required this.flowState,
    this.runners = const [],
    this.statistics = const RaceStatistics(),
  });

  /// Create a copy with updated fields
  RaceModel copyWith({
    int? raceId,
    String? raceName,
    DateTime? raceDate,
    String? location,
    double? distance,
    String? distanceUnit,
    List<Color>? teamColors,
    List<String>? teams,
    String? flowState,
    List<RunnerModel>? runners,
    RaceStatistics? statistics,
  }) {
    return RaceModel(
      raceId: raceId ?? this.raceId,
      raceName: raceName ?? this.raceName,
      raceDate: raceDate ?? this.raceDate,
      location: location ?? this.location,
      distance: distance ?? this.distance,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      teamColors: teamColors ?? this.teamColors,
      teams: teams ?? this.teams,
      flowState: flowState ?? this.flowState,
      runners: runners ?? this.runners,
      statistics: statistics ?? this.statistics,
    );
  }

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson({bool forDatabase = false}) {
    final Map<String, dynamic> json = {
      'race_name': raceName,
      'race_date': raceDate?.toIso8601String(),
      'location': location,
      'distance': distance,
      'distance_unit': distanceUnit,
      'team_colors': jsonEncode(teamColors.map((c) => c.value).toList()),
      'teams': jsonEncode(teams),
      'flow_state': flowState,
    };

    if (!forDatabase) {
      json['race_id'] = raceId;
      json['runners'] = runners.map((r) => r.toJson()).toList();
      json['statistics'] = statistics.toJson();
    }

    return json;
  }

  /// Create from JSON
  factory RaceModel.fromJson(Map<String, dynamic> json) {
    return RaceModel(
      raceId: json['race_id'] ?? 0,
      raceName: json['race_name'] ?? '',
      raceDate:
          json['race_date'] != null ? DateTime.parse(json['race_date']) : null,
      location: json['location'] ?? '',
      distance: (json['distance'] ?? 0).toDouble(),
      distanceUnit: json['distance_unit'] ?? 'mi',
      teamColors: _parseColors(json['team_colors']),
      teams: _parseTeams(json['teams']),
      flowState: json['flow_state'] ?? FLOW_SETUP,
      runners: _parseRunners(json['runners']),
      statistics: RaceStatistics.fromJson(json['statistics'] ?? {}),
    );
  }

  static List<Color> _parseColors(dynamic colorsData) {
    try {
      if (colorsData is String) {
        final List<dynamic> colorValues = jsonDecode(colorsData);
        return colorValues.map((c) => Color(c as int)).toList();
      } else if (colorsData is List) {
        return colorsData.map((c) => Color(c as int)).toList();
      }
    } catch (e) {
      // Return default colors if parsing fails
    }
    return [Colors.blue, Colors.red, Colors.green, Colors.orange];
  }

  static List<String> _parseTeams(dynamic teamsData) {
    try {
      if (teamsData is String) {
        final List<dynamic> teamList = jsonDecode(teamsData);
        return teamList.cast<String>();
      } else if (teamsData is List) {
        return teamsData.cast<String>();
      }
    } catch (e) {
      // Return empty list if parsing fails
    }
    return [];
  }

  static List<RunnerModel> _parseRunners(dynamic runnersData) {
    try {
      if (runnersData is List) {
        return runnersData
            .map((r) => RunnerModel.fromJson(r as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Return empty list if parsing fails
    }
    return [];
  }

  /// Business logic methods

  /// Check if the race setup is complete
  bool get isSetupComplete {
    return raceName.isNotEmpty &&
        location.isNotEmpty &&
        raceDate != null &&
        distance > 0 &&
        distanceUnit.isNotEmpty &&
        teams.isNotEmpty &&
        runners.length >= 5; // Minimum runners requirement
  }

  /// Check if the current flow state is completed
  bool get isCurrentFlowCompleted {
    return flowState.contains(FLOW_COMPLETED_SUFFIX) ||
        flowState == FLOW_FINISHED;
  }

  /// Get the current flow base name without the completed suffix
  String get currentFlowBase {
    if (flowState.contains(FLOW_COMPLETED_SUFFIX)) {
      return flowState.split(FLOW_COMPLETED_SUFFIX).first;
    }
    return flowState;
  }

  /// Get the next flow state
  String? get nextFlowState {
    switch (flowState) {
      case FLOW_SETUP:
        return isSetupComplete ? FLOW_SETUP_COMPLETED : null;
      case FLOW_SETUP_COMPLETED:
        return FLOW_PRE_RACE;
      case FLOW_PRE_RACE_COMPLETED:
        return FLOW_POST_RACE;
      case FLOW_POST_RACE_COMPLETED:
        return FLOW_FINISHED;
      default:
        return null;
    }
  }

  /// Get display-friendly flow state name
  String get flowDisplayName {
    switch (currentFlowBase) {
      case FLOW_SETUP:
        return 'Setup';
      case FLOW_PRE_RACE:
        return 'Pre-Race';
      case FLOW_POST_RACE:
        return 'Post-Race';
      case FLOW_FINISHED:
        return 'Finished';
      default:
        return 'Unknown';
    }
  }

  /// Get runners by team
  Map<String, List<RunnerModel>> get runnersByTeam {
    final Map<String, List<RunnerModel>> result = {};
    for (final team in teams) {
      result[team] = runners.where((r) => r.school == team).toList();
    }
    return result;
  }

  /// Validation methods
  List<String> get validationErrors {
    final errors = <String>[];

    if (raceName.isEmpty) errors.add('Race name is required');
    if (location.isEmpty) errors.add('Location is required');
    if (raceDate == null) errors.add('Race date is required');
    if (distance <= 0) errors.add('Distance must be greater than 0');
    if (distanceUnit.isEmpty) errors.add('Distance unit is required');
    if (teams.isEmpty) errors.add('At least one team is required');
    if (runners.length < 5) errors.add('At least 5 runners are required');

    return errors;
  }

  bool get isValid => validationErrors.isEmpty;

  @override
  String toString() {
    return 'RaceModel(id: $raceId, name: $raceName, teams: ${teams.length}, runners: ${runners.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RaceModel && other.raceId == raceId;
  }

  @override
  int get hashCode => raceId.hashCode;
}

/// Model for individual runners
class RunnerModel {
  final String name;
  final String school;
  final String grade;
  final String bib;
  final int raceId;

  const RunnerModel({
    required this.name,
    required this.school,
    required this.grade,
    required this.bib,
    required this.raceId,
  });

  RunnerModel copyWith({
    String? name,
    String? school,
    String? grade,
    String? bib,
    int? raceId,
  }) {
    return RunnerModel(
      name: name ?? this.name,
      school: school ?? this.school,
      grade: grade ?? this.grade,
      bib: bib ?? this.bib,
      raceId: raceId ?? this.raceId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'school': school,
      'grade': grade,
      'bib': bib,
      'race_id': raceId,
    };
  }

  factory RunnerModel.fromJson(Map<String, dynamic> json) {
    return RunnerModel(
      name: json['name'] ?? '',
      school: json['school'] ?? '',
      grade: json['grade'] ?? '',
      bib: json['bib'] ?? '',
      raceId: json['race_id'] ?? 0,
    );
  }

  @override
  String toString() {
    return 'RunnerModel(name: $name, school: $school, bib: $bib)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RunnerModel && other.raceId == raceId && other.bib == bib;
  }

  @override
  int get hashCode => Object.hash(raceId, bib);
}

/// Statistics for a race
class RaceStatistics {
  final int totalRunners;
  final int totalTeams;
  final int completedRunners;
  final Duration? fastestTime;
  final Duration? averageTime;
  final DateTime? lastUpdated;

  const RaceStatistics({
    this.totalRunners = 0,
    this.totalTeams = 0,
    this.completedRunners = 0,
    this.fastestTime,
    this.averageTime,
    this.lastUpdated,
  });

  RaceStatistics copyWith({
    int? totalRunners,
    int? totalTeams,
    int? completedRunners,
    Duration? fastestTime,
    Duration? averageTime,
    DateTime? lastUpdated,
  }) {
    return RaceStatistics(
      totalRunners: totalRunners ?? this.totalRunners,
      totalTeams: totalTeams ?? this.totalTeams,
      completedRunners: completedRunners ?? this.completedRunners,
      fastestTime: fastestTime ?? this.fastestTime,
      averageTime: averageTime ?? this.averageTime,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_runners': totalRunners,
      'total_teams': totalTeams,
      'completed_runners': completedRunners,
      'fastest_time': fastestTime?.inMilliseconds,
      'average_time': averageTime?.inMilliseconds,
      'last_updated': lastUpdated?.toIso8601String(),
    };
  }

  factory RaceStatistics.fromJson(Map<String, dynamic> json) {
    return RaceStatistics(
      totalRunners: json['total_runners'] ?? 0,
      totalTeams: json['total_teams'] ?? 0,
      completedRunners: json['completed_runners'] ?? 0,
      fastestTime: json['fastest_time'] != null
          ? Duration(milliseconds: json['fastest_time'])
          : null,
      averageTime: json['average_time'] != null
          ? Duration(milliseconds: json['average_time'])
          : null,
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'])
          : null,
    );
  }

  /// Get completion percentage
  double get completionPercentage {
    if (totalRunners == 0) return 0.0;
    return (completedRunners / totalRunners) * 100;
  }

  @override
  String toString() {
    return 'RaceStatistics(runners: $completedRunners/$totalRunners, teams: $totalTeams)';
  }
}
