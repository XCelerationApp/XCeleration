/// Represents a team in the racing application
class TeamParticipant {
  final int? raceId;
  final int? teamId;
  final int? colorOverride;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int? isDirty;

  const TeamParticipant({
    this.raceId,
    this.teamId,
    this.colorOverride,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.isDirty,
  });

  /// Create a Team from a database map
  factory TeamParticipant.fromMap(Map<String, dynamic> map) {
    return TeamParticipant(
      raceId: map['race_id'],
      teamId: map['team_id'],
      colorOverride: map['team_color_override'],
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      deletedAt:
          map['deleted_at'] != null ? DateTime.parse(map['deleted_at']) : null,
      isDirty: map['is_dirty'],
    );
  }

  /// Convert Team to a map for database storage
  Map<String, dynamic> toMap() {
    final map = {
      'race_id': raceId,
      'team_id': teamId,
      'team_color_override': colorOverride,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'is_dirty': isDirty,
    };
    return map;
  }

  /// Create a copy of the team with some fields replaced
  TeamParticipant copyWith({
    int? raceId,
    int? teamId,
    int? colorOverride,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? isDirty,
  }) {
    return TeamParticipant(
      raceId: raceId ?? this.raceId,
      teamId: teamId ?? this.teamId,
      colorOverride: colorOverride ?? this.colorOverride,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  @override
  String toString() {
    return 'TeamParticipant(raceId: $raceId, teamId: $teamId, colorOverride: $colorOverride)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TeamParticipant &&
        other.raceId == raceId &&
        other.teamId == teamId &&
        other.colorOverride == colorOverride;
  }

  @override
  int get hashCode {
    return raceId.hashCode ^ teamId.hashCode ^ colorOverride.hashCode;
  }

  bool get isValid {
    return raceId != null && teamId != null && raceId! > 0 && teamId! > 0;
  }
}
