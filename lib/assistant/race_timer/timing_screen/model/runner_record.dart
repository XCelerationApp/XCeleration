import 'package:flutter/foundation.dart';
import '../../../../utils/enums.dart';
import 'package:flutter/material.dart';

/// Represents a record of a runner's time in a race.
class RunnerRecord {
  /// Unique identifier for the record
  final String id;
  
  /// The time the runner finished the race, as a Duration from the race start time
  final String elapsedTime;
  
  /// The runner's assigned number, if known
  final int? runnerNumber;
  
  /// Whether this record has been confirmed
  final bool isConfirmed;
  
  /// Details about any conflicts with other records
  final ConflictDetails? conflict;

  RecordType type;
  int? place;
  int? previousPlace;
  Color? textColor;
  
  /// Constructor for RunnerRecord
  RunnerRecord({
    required this.id,
    required this.elapsedTime,
    this.runnerNumber,
    this.isConfirmed = false,
    this.conflict,
    this.type = RecordType.runnerTime,
    required this.place,
    this.previousPlace,
    this.textColor,
  });
  
  /// Creates a copy of this record with the given fields replaced
  RunnerRecord copyWith({
    String? id,
    String? elapsedTime,
    int? runnerNumber,
    bool? isConfirmed,
    ConflictDetails? conflict,
    RecordType? type,
    int? place,
    int? previousPlace,
    Color? textColor,
  }) {
    print('text color 2: $textColor');
    print(textColor == Colors.transparent ? null : (textColor ?? this.textColor));
    return RunnerRecord(
      id: id ?? this.id,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      runnerNumber: runnerNumber ?? this.runnerNumber,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      conflict: conflict ?? this.conflict,
      type: type ?? this.type,
      place: place ?? this.place,
      previousPlace: previousPlace ?? this.previousPlace,
      textColor: textColor == Colors.transparent ? null : (textColor ?? this.textColor), 
    );
  }

  
  /// Checks if this record has a conflict that hasn't been resolved
  bool hasConflict() => conflict != null;
  
  /// Checks if this record's conflict has been resolved
  bool isResolved() => conflict?.isResolved ?? true;
  
  /// Converts record to a Map for serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'elapsed_time': elapsedTime,
      'runner_number': runnerNumber,
      'is_confirmed': isConfirmed,
      'conflict': conflict?.toMap(),
      'type': type.toString(),
      'place': place,
      'previous_place': previousPlace,
      'text_color': textColor,
    };
  }
  
  /// Creates a RunnerRecord from a Map
  factory RunnerRecord.fromMap(Map<String, dynamic> map) {
    return RunnerRecord(
      id: map['id'],
      elapsedTime: map['elapsed_time'],
      runnerNumber: map['runner_number'],
      isConfirmed: map['is_confirmed'] ?? false,
      conflict: map['conflict'] != null 
          ? ConflictDetails.fromMap(map['conflict']) 
          : null,
      type: map['type'] ?? RecordType.runnerTime,
      place: map['place'],
      previousPlace: map['previous_place'],
      textColor: map['text_color'],
    );
  }
}

/// Represents details about a conflict between runner records
class ConflictDetails {
  /// Type of conflict (e.g., 'missing_runner', 'extra_runner')
  final RecordType type;
  
  /// Whether the conflict has been resolved
  final bool isResolved;
  
  /// Any additional data relevant to the conflict
  final Map<String, dynamic>? data;
  
  /// Constructor for ConflictDetails
  ConflictDetails({
    required this.type,
    this.isResolved = false,
    this.data,
  });
  
  /// Creates a copy of this conflict with the given fields replaced
  ConflictDetails copyWith({
    RecordType? type,
    bool? isResolved,
    Map<String, dynamic>? data,
  }) {
    return ConflictDetails(
      type: type ?? this.type,
      isResolved: isResolved ?? this.isResolved,
      data: data ?? this.data,
    );
  }
  
  /// Converts conflict details to a Map for serialization
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'is_resolved': isResolved,
      'data': data,
    };
  }
  
  /// Creates a ConflictDetails from a Map
  factory ConflictDetails.fromMap(Map<String, dynamic> map) {
    return ConflictDetails(
      type: map['type'],
      isResolved: map['is_resolved'] ?? false,
      data: map['data'],
    );
  }
}
