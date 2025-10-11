import 'package:flutter/material.dart';

/// Model for storing runner data in the database
class Runner {
  final int raceId;
  final String bibNumber;
  final String? name;
  final String? teamAbbreviation;
  final String? grade;
  final Color? teamColor;
  final DateTime createdAt;

  const Runner({
    required this.raceId,
    required this.bibNumber,
    this.name,
    this.teamAbbreviation,
    this.grade,
    this.teamColor,
    required this.createdAt,
  });

  /// Creates a Runner from a database map
  factory Runner.fromMap(Map<String, dynamic> map) {
    return Runner(
      raceId: map['race_id'] as int,
      bibNumber: map['bib_number'] as String,
      name: map['name'] as String?,
      teamAbbreviation: map['team_abbreviation'] as String?,
      grade: map['grade'] as String?,
      teamColor:
          map['team_color'] != null ? Color(map['team_color'] as int) : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  /// Converts a Runner to a database map
  Map<String, dynamic> toMap() {
    return {
      'race_id': raceId,
      'bib_number': bibNumber,
      'name': name,
      'team_abbreviation': teamAbbreviation,
      'grade': grade,
      'team_color': teamColor?.toARGB32(),
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Creates a copy of this Runner with updated fields
  Runner copyWith({
    int? raceId,
    String? bibNumber,
    String? name,
    String? teamAbbreviation,
    String? grade,
    Color? teamColor,
    DateTime? createdAt,
  }) {
    return Runner(
      raceId: raceId ?? this.raceId,
      bibNumber: bibNumber ?? this.bibNumber,
      name: name ?? this.name,
      teamAbbreviation: teamAbbreviation ?? this.teamAbbreviation,
      grade: grade ?? this.grade,
      teamColor: teamColor ?? this.teamColor,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Runner &&
        other.raceId == raceId &&
        other.bibNumber == bibNumber &&
        other.name == name &&
        other.teamAbbreviation == teamAbbreviation &&
        other.grade == grade &&
        other.teamColor == teamColor &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      raceId,
      bibNumber,
      name,
      teamAbbreviation,
      grade,
      teamColor,
      createdAt,
    );
  }

  @override
  String toString() {
    return 'Runner(raceId: $raceId, bibNumber: $bibNumber, name: $name, teamAbbreviation: $teamAbbreviation, grade: $grade, teamColor: $teamColor, createdAt: $createdAt)';
  }
}
