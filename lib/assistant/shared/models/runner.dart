import 'package:flutter/material.dart';

/// Assistant-side runner model, scoped to a single race recording session.
///
/// **Why this differs from [lib/shared/models/database/runner.dart]:**
/// The shared Runner is a generic Coach-side database entity with UUID-based
/// sync tracking (`uuid`, `isDirty`, `int grade`). This model represents a
/// runner as seen by the Assistant during a live recording: it is always
/// associated with a specific `raceId`, carries display fields
/// (`teamAbbreviation`, `teamColor`) resolved at load time, and uses
/// `String grade` to match the bib-datum encoding used over P2P transport.
/// The two must not be merged: they exist on separate SQLite databases and
/// serve different lifecycle concerns.
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
