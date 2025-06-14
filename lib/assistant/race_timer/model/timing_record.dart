import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'package:xceleration/utils/enums.dart';

/// Represents a record of a runner's time in a race.
class TimingRecord {
  factory TimingRecord.blank() {
    return TimingRecord(
      elapsedTime: '',
      runnerNumber: null,
      isConfirmed: false,
      conflict: null,
      type: RecordType.runnerTime,
      place: null,
      previousPlace: null,
      textColor: null,
      runnerId: null,
      raceId: null,
      name: '',
      school: '',
      grade: null,
      bib: '',  
      error: null,
    );
  }
  /// The time the runner finished the race, as a Duration from the race start time
  String elapsedTime;

  /// The runner's assigned number, if known
  final String? runnerNumber;

  /// Whether this record has been confirmed
  bool isConfirmed;

  /// Details about any conflicts with other records
  ConflictDetails? conflict;

  RecordType type;
  int? place;
  int? previousPlace;
  dynamic textColor;

  // Runner properties
  int? runnerId;
  int? raceId;
  String? name;
  String? school;
  int? grade;
  String? bib;
  String? error;

  /// Constructor for TimingRecord
  TimingRecord({
    required this.elapsedTime,
    this.runnerNumber,
    this.isConfirmed = false,
    this.conflict,
    this.type = RecordType.runnerTime,
    this.place,
    this.previousPlace,
    this.textColor,
    this.runnerId,
    this.raceId,
    this.name,
    this.school,
    this.grade,
    this.bib,
    this.error,
  });

  /// Creates a copy of this record with the given fields replaced
  TimingRecord copyWith({
    String? id,
    String? elapsedTime,
    String? runnerNumber,
    bool? isConfirmed,
    ConflictDetails? conflict,
    RecordType? type,
    int? place,
    int? previousPlace,
    dynamic textColor,
    int? runnerId,
    int? raceId,
    String? name,
    String? school,
    int? grade,
    String? bib,
    String? error,
    bool clearTextColor = false,
    bool clearConflict = false,
  }) {
    return TimingRecord(
      elapsedTime: elapsedTime ?? this.elapsedTime,
      runnerNumber: runnerNumber ?? this.runnerNumber,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      conflict: clearConflict ? null : (conflict ?? this.conflict),
      type: type ?? this.type,
      place: place ?? this.place,
      previousPlace: previousPlace ?? this.previousPlace,
      textColor: clearTextColor ? null : (textColor ?? this.textColor),
      runnerId: runnerId ?? this.runnerId,
      raceId: raceId ?? this.raceId,
      name: name ?? this.name,
      school: school ?? this.school,
      grade: grade ?? this.grade,
      bib: bib ?? this.bib,
      error: error ?? this.error,
    );
  }

  /// Checks if this record has a conflict that hasn't been resolved
  bool hasConflict() => conflict != null;

  /// Checks if this record's conflict has been resolved
  bool isResolved() => conflict?.isResolved ?? true;

  /// Converts this TimingRecord to a RunnerRecord
  RunnerRecord? get runnerRecord {
    if (raceId == null ||
        name == null ||
        school == null ||
        grade == null ||
        bib == null) {
      return null;
    }
    return RunnerRecord(
      runnerId: runnerId,
      raceId: raceId!,
      name: name!,
      school: school!,
      grade: grade!,
      bib: bib!,
      error: error,
    );
  }

  /// Converts record to a Map for serialization
  Map<String, dynamic> toMap() {
    return {
      'elapsed_time': elapsedTime,
      'runner_number': runnerNumber,
      'is_confirmed': isConfirmed,
      'conflict': conflict?.toMap(),
      'type': type.toString(),
      'place': place,
      'previous_place': previousPlace,
      'text_color': textColor,
      'runner_id': runnerId,
      'race_id': raceId,
      'name': name,
      'school': school,
      'grade': grade,
      'bib': bib,
      'error': error,
    };
  }

  /// Creates a TimingRecord from a Map
  factory TimingRecord.fromMap(Map<String, dynamic> map,
      {bool database = false}) {
    return TimingRecord(
      elapsedTime: database ? map['finish_time'] : map['elapsed_time'],
      runnerNumber: map['runner_number'],
      isConfirmed: map['is_confirmed'] ?? false,
      conflict: map['conflict'] != null
          ? ConflictDetails.fromMap(map['conflict'])
          : null,
      type: map['type'] ?? RecordType.runnerTime,
      place: map['place'],
      previousPlace: map['previous_place'],
      textColor: map['text_color'],
      runnerId: map['runner_id'],
      raceId: map['race_id'],
      name: map['name'],
      school: map['school'],
      grade: map['grade'],
      bib: database ? map['bib_number'] : map['bib'],
      error: map['error'],
    );
  }
}

/// Represents a conflict between records
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
