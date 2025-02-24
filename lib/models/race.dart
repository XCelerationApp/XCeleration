import 'package:flutter/material.dart';
import 'dart:convert';

class Race {
  final int raceId;
  final String raceName;
  final DateTime raceDate;
  final String location;
  final double distance;
  final String distanceUnit;
  final List<Color> teamColors;
  final List<String> teams;
  final String flowState;

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
    final List<dynamic> teamColorsList = jsonDecode(race['team_colors']);
    final List<dynamic> teamsList = jsonDecode(race['teams']);
    
    return Race(
      raceId: int.parse(race['race_id'].toString()),
      raceName: race['race_name'],
      raceDate: DateTime.parse(race['race_date']),
      location: race['location'],
      distance: double.parse(race['distance'].toString()),
      distanceUnit: race['distance_unit'],
      teamColors: teamColorsList.map((x) => Color(int.parse(x.toString()))).toList(),
      teams: teamsList.cast<String>(),
      flowState: race['flow_state'] ?? 'setup',
    );
  }

  // Convert a Race into a Map
  Map<String, dynamic> toMap() {
    return {
      'race_id': raceId,
      'race_name': raceName,
      'race_date': raceDate.toIso8601String(),
      'location': location,
      'distance': distance,
      'distance_unit': distanceUnit,
      'team_colors': jsonEncode(teamColors.map((c) => c.value).toList()),
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

  // Getters for backward compatibility
  String get race_name => raceName;
  String get race_location => location;
  DateTime get race_date => raceDate;
  double get race_distance => distance;
  String get race_distance_unit => distanceUnit;
  int get race_id => raceId;
  List<Color> get race_team_colors => teamColors;
  List<String> get race_teams => teams;
}