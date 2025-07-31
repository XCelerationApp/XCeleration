import 'package:flutter/material.dart';
import 'runner.dart';
import 'team.dart';

/// Represents a race result with runner and timing information
class RaceResult {
  final int? resultId;
  final int? raceId;
  final Runner? runner;
  final Team? team;
  int? place;
  final Duration? finishTime;
  final DateTime? createdAt;

  RaceResult({
    this.resultId,
    this.raceId,
    this.runner,
    this.team,
    this.place,
    this.finishTime,
    this.createdAt,
  });

  /// Create a RaceResult from a database map with joined data
  factory RaceResult.fromMap(Map<String, dynamic> map) {
    // Extract runner information
    final runner = Runner(
      runnerId: map['runner_id'],
      name: map['name'],
      bibNumber: map['bib_number'],
      grade: map['grade'],
    );

    // Extract team information
    final team = Team(
      teamId: map['team_id'],
      name: map['team_name'] ?? map['team'],
      abbreviation: map['team_abbreviation'],
      color: Color(map['team_color'] ?? 0xFF2196F3),
    );

    // Parse finish time
    Duration? finishTime;
    if (map['finish_time'] != null) {
      if (map['finish_time'] is int) {
        finishTime = Duration(milliseconds: map['finish_time']);
      } else if (map['finish_time'] is String) {
        // Handle formatted time strings (e.g., "12:34.56")
        finishTime = _parseTimeString(map['finish_time']);
      }
    }

    return RaceResult(
      resultId: map['result_id'],
      raceId: map['race_id'],
      runner: runner,
      team: team,
      place: map['place'],
      finishTime: finishTime,
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  /// Parse a time string like "12:34.56" into a Duration
  static Duration? _parseTimeString(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final secondsParts = parts[1].split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1
            ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3))
            : 0;

        return Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Convert to database map
  Map<String, dynamic> toMap(
      {bool includeId = false, bool includeUpdatedAt = false}) {
    final Map<String, dynamic> map = {
      'race_id': raceId,
      'runner_id': runner?.runnerId,
      'place': place,
      'finish_time': finishTime?.inMilliseconds,
    };

    if (includeId && resultId != null) {
      map['result_id'] = resultId!;
    }
    if (includeUpdatedAt) {
      map['updated_at'] = DateTime.now().toIso8601String();
    }

    return map;
  }

  /// Get formatted finish time string (e.g., "12:34.56")
  String get formattedFinishTime {
    if (finishTime == null) return '';

    final minutes = finishTime!.inMinutes;
    final seconds = finishTime!.inSeconds % 60;
    final milliseconds = finishTime!.inMilliseconds % 1000;

    return '$minutes:${seconds.toString().padLeft(2, '0')}.${(milliseconds ~/ 10).toString().padLeft(2, '0')}';
  }

  /// Create a copy with some fields replaced
  RaceResult copyWith({
    int? resultId,
    int? raceId,
    Runner? runner,
    Team? team,
    int? place,
    Duration? finishTime,
    DateTime? createdAt,
  }) {
    return RaceResult(
      resultId: resultId ?? this.resultId,
      raceId: raceId ?? this.raceId,
      runner: runner ?? this.runner,
      team: team ?? this.team,
      place: place ?? this.place,
      finishTime: finishTime ?? this.finishTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static RaceResult copy(RaceResult result) {
    return RaceResult(
      resultId: result.resultId,
      raceId: result.raceId,
      runner: result.runner,
      team: result.team,
      place: result.place,
      finishTime: result.finishTime,
      createdAt: result.createdAt,
    );
  }
  @override
  String toString() {
    return 'RaceResult(place: $place, runner: ${runner?.name}, time: $formattedFinishTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RaceResult &&
        other.resultId == resultId &&
        other.raceId == raceId &&
        other.runner == runner &&
        other.place == place &&
        other.finishTime == finishTime;
  }

  int comparePlaceTo(RaceResult other) {
    if (place == null && other.place == null) return 0;
    if (place == null) return 1;
    if (other.place == null) return -1;
    return place!.compareTo(other.place!);
  }

  int compareTimeTo(RaceResult other) {
    if (finishTime == null && other.finishTime == null) return 0;
    if (finishTime == null) return 1;
    if (other.finishTime == null) return -1;
    return finishTime!.compareTo(other.finishTime!);
  }

  @override
  int get hashCode {
    return resultId.hashCode ^
        raceId.hashCode ^
        runner.hashCode ^
        place.hashCode ^
        finishTime.hashCode;
  }

  bool get isValid {
    return resultId != null &&
        raceId != null &&
        runner != null &&
        runner!.isValid &&
        team != null &&
        team!.isValid &&
        place != null &&
        finishTime != null;
  }
}
