import 'package:intl/intl.dart';

/// Represents a timing record for a race participant
class TimingRecord {
  final int? id;
  final String elapsedTime;
  final DateTime timestamp;
  final String? bibNumber;
  final String? runnerName;
  final int? place;
  final bool isConfirmed;
  final Map<String, dynamic>? metadata;

  TimingRecord({
    this.id,
    required this.elapsedTime,
    required this.timestamp,
    this.bibNumber,
    this.runnerName,
    this.place,
    this.isConfirmed = false,
    this.metadata,
  });

  /// Create a copy with updated fields
  TimingRecord copyWith({
    int? id,
    String? elapsedTime,
    DateTime? timestamp,
    String? bibNumber,
    String? runnerName,
    int? place,
    bool? isConfirmed,
    Map<String, dynamic>? metadata,
  }) {
    return TimingRecord(
      id: id ?? this.id,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      timestamp: timestamp ?? this.timestamp,
      bibNumber: bibNumber ?? this.bibNumber,
      runnerName: runnerName ?? this.runnerName,
      place: place ?? this.place,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'elapsed_time': elapsedTime,
      'timestamp': timestamp.toIso8601String(),
      'bib_number': bibNumber,
      'runner_name': runnerName,
      'place': place,
      'is_confirmed': isConfirmed ? 1 : 0,
      'metadata': metadata != null ? metadata.toString() : null,
    };
  }

  /// Create from JSON (database)
  factory TimingRecord.fromJson(Map<String, dynamic> json) {
    return TimingRecord(
      id: json['id'],
      elapsedTime: json['elapsed_time'],
      timestamp: DateTime.parse(json['timestamp']),
      bibNumber: json['bib_number'],
      runnerName: json['runner_name'],
      place: json['place'],
      isConfirmed: (json['is_confirmed'] ?? 0) == 1,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }

  /// Format timestamp for display
  String get formattedTimestamp {
    return DateFormat('HH:mm:ss').format(timestamp);
  }

  /// Check if this record has a valid bib number
  bool get hasBibNumber => bibNumber != null && bibNumber!.isNotEmpty;

  /// Check if this record is complete (has all required data)
  bool get isComplete =>
      hasBibNumber && runnerName != null && runnerName!.isNotEmpty;

  @override
  String toString() {
    return 'TimingRecord(id: $id, time: $elapsedTime, bib: $bibNumber, runner: $runnerName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimingRecord &&
        other.id == id &&
        other.elapsedTime == elapsedTime &&
        other.timestamp == timestamp &&
        other.bibNumber == bibNumber;
  }

  @override
  int get hashCode {
    return Object.hash(id, elapsedTime, timestamp, bibNumber);
  }
}
