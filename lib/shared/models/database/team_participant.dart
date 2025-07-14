
/// Represents a team in the racing application
class TeamParticipant {
  final int? raceId;
  final int? teamId;
  final int? colorOverride;

  const TeamParticipant({
    this.raceId,
    this.teamId,
    this.colorOverride,
  });

  /// Create a Team from a database map
  factory TeamParticipant.fromMap(Map<String, dynamic> map) {
    return TeamParticipant(
      raceId: map['race_id'],
      teamId: map['team_id'],
      colorOverride: map['color_override'],
    );
  }

  /// Convert Team to a map for database storage
  Map<String, dynamic> toMap() {
    final map = {
      'race_id': raceId,
      'team_id': teamId,
      'color_override': colorOverride,
    };
    return map;
  }

  /// Create a copy of the team with some fields replaced
  TeamParticipant copyWith({
    int? raceId,
    int? teamId,
    int? colorOverride,
  }) {
    return TeamParticipant(
      raceId: raceId ?? this.raceId,
      teamId: teamId ?? this.teamId,
      colorOverride: colorOverride ?? this.colorOverride,
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
    return raceId.hashCode ^
        teamId.hashCode ^
        colorOverride.hashCode;
  }

  bool get isValid {
    return raceId != null &&
        teamId != null &&
        raceId! > 0 &&
        teamId! > 0 &&
        colorOverride != null;
  }
}
