/// Represents the result of a racer in a specific race
class RaceResult {
  /// The ID of the race
  final int raceId;
  
  /// The finishing place of the runner
  final int? place;
  
  /// The ID of the runner (may be null if bib wasn't resolved)
  final int? runnerId;
  
  /// The time the runner finished, formatted as hh:mm:ss.ms
  final String finishTime;
  
  /// Creates a new race result
  const RaceResult({
    required this.raceId,
    this.place,
    this.runnerId,
    required this.finishTime,
  });
  
  /// Creates a copy of this result with specified fields replaced
  RaceResult copyWith({
    int? raceId,
    int? place,
    int? runnerId,
    String? finishTime,
  }) {
    return RaceResult(
      raceId: raceId ?? this.raceId,
      place: place ?? this.place,
      runnerId: runnerId ?? this.runnerId,
      finishTime: finishTime ?? this.finishTime,
    );
  }
  
  /// Converts this race result to a map for database storage
  Map<String, dynamic> toMap({bool database = false}) {
    if (database) {
      return {
        'race_id': raceId,
        'runner_id': runnerId,
        'place': place,
        'finish_time': finishTime,
      };
    }
    return {
      'race_id': raceId,
      'place': place,
      'runner_id': runnerId,
      'finish_time': finishTime,
    };
  }
  
  /// Creates a race result from a database map
  factory RaceResult.fromMap(Map<String, dynamic> map) {
    return RaceResult(
      raceId: map['race_id'],
      place: map['place'],
      runnerId: map['runner_id'],
      finishTime: map['finish_time'],
    );
  }
  
  @override
  String toString() {
    return 'RaceResult(raceId: $raceId, place: $place, runnerId: $runnerId, finishTime: $finishTime)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is RaceResult &&
      other.raceId == raceId &&
      other.place == place &&
      other.runnerId == runnerId &&
      other.finishTime == finishTime;
  }
  
  @override
  int get hashCode {
    return raceId.hashCode ^
      place.hashCode ^
      runnerId.hashCode ^
      finishTime.hashCode;
  }
}
