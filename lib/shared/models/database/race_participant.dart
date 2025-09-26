/// Represents a team in the racing application
class RaceParticipant {
  final int? raceId;
  final int? runnerId;
  final int? teamId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int? isDirty;

  const RaceParticipant({
    this.raceId,
    this.runnerId,
    this.teamId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.isDirty,
  });

  /// Create a Team from a database map
  factory RaceParticipant.fromMap(Map<String, dynamic> map) {
    return RaceParticipant(
      raceId: map['race_id'],
      runnerId: map['runner_id'],
      teamId: map['team_id'],
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
      'runner_id': runnerId,
      'team_id': teamId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'is_dirty': isDirty,
    };

    return map;
  }

  /// Create a copy of the team with some fields replaced
  RaceParticipant copyWith({
    int? raceId,
    int? runnerId,
    int? teamId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? isDirty,
  }) {
    return RaceParticipant(
      raceId: raceId ?? this.raceId,
      runnerId: runnerId ?? this.runnerId,
      teamId: teamId ?? this.teamId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  @override
  String toString() {
    return 'RaceParticipant(raceId: $raceId, runnerId: $runnerId, teamId: $teamId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RaceParticipant &&
        other.raceId == raceId &&
        other.runnerId == runnerId &&
        other.teamId == teamId;
  }

  @override
  int get hashCode {
    return raceId.hashCode ^ runnerId.hashCode ^ teamId.hashCode;
  }

  bool get isValid {
    return raceId != null &&
        runnerId != null &&
        teamId != null &&
        raceId! > 0 &&
        runnerId! > 0 &&
        teamId! > 0;
  }
}
