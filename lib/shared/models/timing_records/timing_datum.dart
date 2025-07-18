import 'package:xceleration/core/utils/enums.dart';
import 'conflict.dart';
import 'package:xceleration/core/utils/time_formatter.dart';

class TimingDatum {
  /// The time the runner finished the race, as a Duration from the race start time
  String time;

  // Conflict
  Conflict? conflict;

  /// Constructor for TimingDatum
  TimingDatum({
    required this.time,
    this.conflict,
  });

  bool get hasConflict => conflict != null;

  /// Factory constructor for creating a blank TimeRecord
  factory TimingDatum.blank() {
    return TimingDatum(time: '');
  }

  /// Creates a copy of this record with the given fields replaced
  TimingDatum copyWith({
    String? time,
    Conflict? conflict,
  }) {
    return TimingDatum(
      time: time ?? this.time,
      conflict: conflict ?? this.conflict,
    );
  }

  @override
  String toString() {
    return 'TimingData(time: $time, conflict: (${conflict == null ? 'null' : conflict.toString()})';
  }

  String encode() {
    if (conflict == null) {
      return time;
    }
    return '${_compressionMap[conflict!.type]} ${conflict!.offBy} $time';
  }

  factory TimingDatum.fromEncodedString(String encodedString) {
    if (_compressionMap.values.contains(encodedString)) {
      final parts = encodedString.split(' ');
      if (parts.length != 3) {
        throw Exception('Invalid encoded timing string: $encodedString');
      }
      return TimingDatum(time: parts[2], conflict: Conflict(type: _decompressionMap[parts[0]]!, offBy: int.parse(parts[1])));
    } else if (encodedString == 'TBD' || TimeFormatter.isDuration(encodedString)) {
      return TimingDatum(time: encodedString);
    }
    throw Exception('Invalid encoded timing string: $encodedString');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimingDatum &&
        other.time == time &&
        other.conflict == conflict;
  }

  @override
  int get hashCode {
    return Object.hash(time, conflict);
  }
}

const Map<ConflictType, String> _compressionMap = {
  ConflictType.confirmRunner: 'CR',
  ConflictType.missingTime: 'MT',
  ConflictType.extraTime: 'ET',
};

const Map<String, ConflictType> _decompressionMap = {
  'CR': ConflictType.confirmRunner,
  'MT': ConflictType.missingTime,
  'ET': ConflictType.extraTime,
};