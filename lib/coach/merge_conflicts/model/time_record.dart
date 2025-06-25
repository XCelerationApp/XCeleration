import '../../../utils/enums.dart';

/// Legacy TimeRecord class for merge conflicts compatibility
/// This maintains the interface expected by the merge conflicts system
class TimeRecord {
  String elapsedTime;
  int? runnerNumber;
  bool isConfirmed;
  ConflictDetails? conflict;
  RecordType type;
  int? place;
  int? previousPlace;
  String? textColor;
  int? runnerId;
  int? raceId;
  String? name;
  String? school;
  int? grade;
  String? bib;
  String? error;

  TimeRecord({
    required this.elapsedTime,
    this.runnerNumber,
    this.isConfirmed = false,
    this.conflict,
    required this.type,
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

  /// Create a blank TimeRecord
  factory TimeRecord.blank() {
    return TimeRecord(
      elapsedTime: '',
      isConfirmed: false,
      type: RecordType.runnerTime,
    );
  }

  /// Create a copy with updated fields
  TimeRecord copyWith({
    String? elapsedTime,
    int? runnerNumber,
    bool? isConfirmed,
    ConflictDetails? conflict,
    RecordType? type,
    int? place,
    int? previousPlace,
    String? textColor,
    int? runnerId,
    int? raceId,
    String? name,
    String? school,
    int? grade,
    String? bib,
    String? error,
  }) {
    return TimeRecord(
      elapsedTime: elapsedTime ?? this.elapsedTime,
      runnerNumber: runnerNumber ?? this.runnerNumber,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      conflict: conflict ?? this.conflict,
      type: type ?? this.type,
      place: place ?? this.place,
      previousPlace: previousPlace ?? this.previousPlace,
      textColor: textColor ?? this.textColor,
      runnerId: runnerId ?? this.runnerId,
      raceId: raceId ?? this.raceId,
      name: name ?? this.name,
      school: school ?? this.school,
      grade: grade ?? this.grade,
      bib: bib ?? this.bib,
      error: error ?? this.error,
    );
  }

  /// Convert to map for database storage
  Map<String, dynamic> toMap() {
    return {
      'elapsedTime': elapsedTime,
      'runnerNumber': runnerNumber,
      'isConfirmed': isConfirmed,
      'conflict': conflict?.toMap(),
      'type': type.toString(),
      'place': place,
      'previousPlace': previousPlace,
      'textColor': textColor,
      'runnerId': runnerId,
      'raceId': raceId,
      'name': name,
      'school': school,
      'grade': grade,
      'bib': bib,
      'error': error,
    };
  }

  /// Create from map
  factory TimeRecord.fromMap(Map<String, dynamic> map) {
    return TimeRecord(
      elapsedTime: map['elapsedTime'] ?? '',
      runnerNumber: map['runnerNumber'],
      isConfirmed: map['isConfirmed'] ?? false,
      conflict: map['conflict'] != null
          ? ConflictDetails.fromMap(map['conflict'])
          : null,
      type: RecordType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => RecordType.runnerTime,
      ),
      place: map['place'],
      previousPlace: map['previousPlace'],
      textColor: map['textColor'],
      runnerId: map['runnerId'],
      raceId: map['raceId'],
      name: map['name'],
      school: map['school'],
      grade: map['grade'],
      bib: map['bib'],
      error: map['error'],
    );
  }

  @override
  String toString() {
    return 'TimeRecord(place: $place, time: $elapsedTime, type: $type, confirmed: $isConfirmed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeRecord &&
        other.elapsedTime == elapsedTime &&
        other.place == place &&
        other.type == type;
  }

  @override
  int get hashCode {
    return Object.hash(elapsedTime, place, type);
  }
}

/// Conflict details for time records
class ConflictDetails {
  final RecordType type;
  final Map<String, dynamic>? data;

  ConflictDetails({
    required this.type,
    this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'data': data,
    };
  }

  factory ConflictDetails.fromMap(Map<String, dynamic> map) {
    return ConflictDetails(
      type: map['type'] ?? '',
      data: map['data'],
    );
  }

  @override
  String toString() {
    return 'ConflictDetails(type: $type)';
  }
}
