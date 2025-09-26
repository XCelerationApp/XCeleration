import 'package:flutter/material.dart';

/// Represents a team in the racing application
class Team {
  final int? teamId;
  final String? uuid;
  final String? name;
  final String? abbreviation;
  final Color? color;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int? isDirty;

  const Team({
    this.teamId,
    this.uuid,
    this.name,
    this.abbreviation,
    this.color,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.isDirty,
  });

  /// Create a Team from a database map
  factory Team.fromMap(Map<String, dynamic> map) {
    return Team(
      teamId: map['team_id'],
      uuid: map['uuid'],
      name: map['name'],
      abbreviation: map['abbreviation'],
      color: Color(map['color'] ?? 0xFF2196F3), // Default blue if null
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      deletedAt:
          map['deleted_at'] != null ? DateTime.parse(map['deleted_at']) : null,
      isDirty: map['is_dirty'],
    );
  }

  /// Create a Team from a race team participation map (includes color override)
  factory Team.fromRaceParticipationMap(Map<String, dynamic> map) {
    final colorOverride = map['team_color_override'];
    if (colorOverride is int) {
      return Team.fromMap(map).copyWith(
        color: Color(colorOverride),
      );
    }
    return Team.fromMap(map);
  }

  /// Convert Team to a map for database storage
  Map<String, dynamic> toMap() {
    final map = {
      'name': name,
      'abbreviation': abbreviation,
      'color': color?.toARGB32(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'is_dirty': isDirty ?? 0,
      'team_id': teamId,
    };
    return map;
  }

  /// Create a copy of the team with some fields replaced
  Team copyWith({
    int? teamId,
    String? uuid,
    String? name,
    String? abbreviation,
    Color? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? isDirty,
  }) {
    return Team(
      teamId: teamId ?? this.teamId,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      abbreviation: abbreviation ?? this.abbreviation,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  /// Generate a team abbreviation from the team name
  static String generateAbbreviation(String teamName) {
    if (teamName.isEmpty) return '';

    // Split by spaces and take first letter of each word
    final words = teamName.trim().split(' ');
    final initials =
        words.map((word) => word.isNotEmpty ? word[0] : '').join('');

    // Return up to 3 characters, converted to uppercase
    return initials.length >= 3
        ? initials.substring(0, 3).toUpperCase()
        : initials.toUpperCase();
  }

  /// Generate a distinct color for a team based on index
  static Color generateColor(int index) {
    // Generate distinct colors using HSL color space
    final hue = (360 / 8 * index) % 360; // Spread across color wheel
    return HSLColor.fromAHSL(1.0, hue, 0.7, 0.5).toColor();
  }

  @override
  String toString() {
    return 'Team(id: $teamId, uuid: $uuid, name: $name, abbreviation: $abbreviation, color: ${color?.toARGB32()})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Team &&
        other.teamId == teamId &&
        other.uuid == uuid &&
        other.name == name &&
        other.abbreviation == abbreviation &&
        other.color == color &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.deletedAt == deletedAt &&
        other.isDirty == isDirty;
  }

  @override
  int get hashCode {
    return teamId.hashCode ^
        uuid.hashCode ^
        name.hashCode ^
        abbreviation.hashCode ^
        color.hashCode ^
        (createdAt?.hashCode ?? 0) ^
        (updatedAt?.hashCode ?? 0) ^
        (deletedAt?.hashCode ?? 0) ^
        (isDirty ?? 0).hashCode;
  }

  bool get isValid {
    return name != null &&
        name!.isNotEmpty &&
        abbreviation != null &&
        abbreviation!.isNotEmpty &&
        color != null;
  }
}
