/// Represents a team in the racing application
class RaceParticipant {
  final int? raceId;
  final int? runnerId;
  final int? teamId;

  const RaceParticipant({
    this.raceId,
    this.runnerId,
    this.teamId,
  });

  /// Create a Team from a database map
  factory RaceParticipant.fromMap(Map<String, dynamic> map) {
    return RaceParticipant(
      raceId: map['race_id'],
      runnerId: map['runner_id'],
      teamId: map['team_id'],
    );
  }

  /// Convert Team to a map for database storage
  Map<String, dynamic> toMap({bool includeId = false}) {
    final map = {
      'race_id': raceId,
      'runner_id': runnerId,
      'team_id': teamId,
    };

    if (includeId && teamId != null) {
      map['team_id'] = teamId!;
    }

    return map;
  }

  /// Create a copy of the team with some fields replaced
  RaceParticipant copyWith({
    int? raceId,
    int? runnerId,
    int? teamId,
  }) {
    return RaceParticipant(
      raceId: raceId ?? this.raceId,
      runnerId: runnerId ?? this.runnerId,
      teamId: teamId ?? this.teamId,
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
