import 'package:flutter/material.dart';
import 'dart:convert';

toRace(Map<String, dynamic> race) {
    final List<dynamic> teamColorsList = jsonDecode(race['team_colors']);
    final List<dynamic> teamsList = jsonDecode(race['teams']);
    
    return Race(
        raceId: race['race_id'],
        raceName: race['race_name'],
        raceDate: DateTime.parse(race['race_date']),
        location: race['location'],
        distance: race['distance'],
        teamColors: teamColorsList.map((x) => Color(int.parse(x))).toList(),
        teams: teamsList.cast<String>(),
    );
}

class Race {
  final int raceId;
  final String raceName;
  final DateTime raceDate;
  final String location;
  final String distance;
  final List<Color> teamColors;
  final List<String> teams;

  Race({
    required this.raceId,
    required this.raceName,
    required this.raceDate,
    required this.location,
    required this.distance,
    required this.teamColors,
    required this.teams,
  });

  // You can add getters if needed
  String get race_name => raceName;
  String get race_location => location;
  DateTime get race_date => raceDate;
  String get race_distance => distance;
  int get race_id => raceId;
  List<Color> get race_team_colors => teamColors;
  List<String> get race_teams => teams;
}