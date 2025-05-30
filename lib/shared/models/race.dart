// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'dart:convert';

class Race {
  final int raceId;
  final String raceName;
  final DateTime? raceDate;
  final String location;
  final double distance;
  final String distanceUnit;
  final List<Color> teamColors;
  final List<String> teams;
  final String flowState;
  
  // Flow state static constants
  static const String FLOW_SETUP = 'setup';
  static const String FLOW_SETUP_COMPLETED = 'setup-completed';
  static const String FLOW_PRE_RACE = 'pre-race';
  static const String FLOW_PRE_RACE_COMPLETED = 'pre-race-completed';
  static const String FLOW_POST_RACE = 'post-race';
  static const String FLOW_FINISHED = 'finished';
  
  // Suffix for completed states
  static const String FLOW_COMPLETED_SUFFIX = '-completed';
  
  // Flow sequence for progression
  static const List<String> FLOW_SEQUENCE = [
    FLOW_SETUP,
    FLOW_SETUP_COMPLETED,
    FLOW_PRE_RACE,
    FLOW_PRE_RACE_COMPLETED,
    FLOW_POST_RACE,
    FLOW_FINISHED
  ];

  Race({
    required this.raceId,
    required this.raceName,
    required this.raceDate,
    required this.location,
    required this.distance,
    required this.distanceUnit,
    required this.teamColors,
    required this.teams,
    required this.flowState,
  });

  // Create a Race from JSON
  static Race fromJson(Map<String, dynamic> race) {
    List<dynamic> teamColorsList;
    List<dynamic> teamsList;
    
    // Handle team_colors - could be string or binary data
    if (race['team_colors'] is String) {
      teamColorsList = jsonDecode(race['team_colors']);
    } else {
      // If it's already a List or some other format, try to use it directly
      try {
        teamColorsList = race['team_colors'] is List 
            ? race['team_colors'] 
            : jsonDecode(race['team_colors'].toString());
      } catch (e) {
        // Fallback to empty list if decoding fails
        teamColorsList = [];
      }
    }
    
    // Handle teams - could be string or binary data
    if (race['teams'] is String) {
      teamsList = jsonDecode(race['teams']);
    } else {
      // If it's already a List or some other format, try to use it directly
      try {
        teamsList = race['teams'] is List 
            ? race['teams'] 
            : jsonDecode(race['teams'].toString());
      } catch (e) {
        // Fallback to empty list if decoding fails
        teamsList = [];
      }
    }
    Logger.d(race['flow_state']);

    return Race(
      raceId: int.parse(race['race_id'].toString()),
      raceName: race['race_name'],
      raceDate: race['race_date'] != null ? DateTime.parse(race['race_date']) : null,
      location: race['location'],
      distance: double.parse(race['distance'].toString()),
      distanceUnit: race['distance_unit'],
      teamColors:
          teamColorsList.map((x) => Color(int.parse(x.toString()))).toList(),
      teams: teamsList.cast<String>(),
      flowState: race['flow_state'] ?? FLOW_SETUP,
    );
  }

  // Convert a Race into a Map
  Map<String, dynamic> toMap({bool database = false}) {
    if (database) {
      return {
        'race_name': raceName,
        'race_date': raceDate?.toIso8601String(),
        'location': location,
        'distance': distance,
        'distance_unit': distanceUnit,
        'team_colors': jsonEncode(teamColors.map((c) => c.toARGB32()).toList()),
        'teams': jsonEncode(teams),
        'flow_state': flowState,
      };
    }
    return {
      'race_id': raceId,
      'race_name': raceName,
      'race_date': raceDate?.toIso8601String(),
      'location': location,
      'distance': distance,
      'distance_unit': distanceUnit,
      'team_colors': jsonEncode(teamColors.map((c) => c.toARGB32()).toList()),
      'teams': jsonEncode(teams),
      'flow_state': flowState,
    };
  }

  // Create a copy of Race with some fields replaced
  Race copyWith({
    int? raceId,
    String? raceName,
    DateTime? raceDate,
    String? location,
    double? distance,
    String? distanceUnit,
    List<Color>? teamColors,
    List<String>? teams,
    String? flowState,
  }) {
    return Race(
      raceId: raceId ?? this.raceId,
      raceName: raceName ?? this.raceName,
      raceDate: raceDate ?? this.raceDate,
      location: location ?? this.location,
      distance: distance ?? this.distance,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      teamColors: teamColors ?? this.teamColors,
      teams: teams ?? this.teams,
      flowState: flowState ?? this.flowState,
    );
  }
  
  // Returns true if the current flow state is a completed state
  bool get isCurrentFlowCompleted {
    return flowState.contains(FLOW_COMPLETED_SUFFIX) || flowState == FLOW_FINISHED;
  }
  
  // Returns the current flow name without the '-completed' suffix
  String get currentFlowBase {
    if (flowState.contains(FLOW_COMPLETED_SUFFIX)) {
      return flowState.split(FLOW_COMPLETED_SUFFIX).first;
    }
    return flowState;
  }
  
  // Get the display name for the next flow
  String get nextFlowDisplayName {
    if (flowState == FLOW_SETUP) return 'Pre-Race';
    if (flowState == FLOW_SETUP_COMPLETED) return 'Pre-Race';
    if (flowState == FLOW_PRE_RACE) return 'Post-Race';
    if (flowState == FLOW_PRE_RACE_COMPLETED) return 'Post-Race';
    if (flowState == FLOW_POST_RACE) return 'Finishing';
    // if (flowState == FLOW_POST_RACE_COMPLETED) return 'Finishing';
    return '';
  }
  
  // Get the state for the next flow
  String get nextFlowState {
    int currentIndex = FLOW_SEQUENCE.indexOf(flowState);
    if (currentIndex >= 0 && currentIndex < FLOW_SEQUENCE.length - 1) {
      return FLOW_SEQUENCE[currentIndex + 1];
    }
    return flowState; // Return current if at the end
  }
  
  // Mark the current flow as completed
  String get completedFlowState {
    if (flowState == FLOW_SETUP) return FLOW_SETUP_COMPLETED;
    if (flowState == FLOW_PRE_RACE) return FLOW_PRE_RACE_COMPLETED;
    // if (flowState == FLOW_POST_RACE) return FLOW_POST_RACE_COMPLETED;
    // Already completed or at finished state
    return flowState;
  }

  // Getters for backward compatibility
  String get race_name => raceName;
  String get race_location => location;
  DateTime? get race_date => raceDate;
  double get race_distance => distance;
  String get race_distance_unit => distanceUnit;
  int get race_id => raceId;
  List<Color> get race_team_colors => teamColors;
  List<String> get race_teams => teams;
}
