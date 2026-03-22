import 'dart:convert';

/// Assistant-side recording session metadata.
///
/// **Why this differs from [lib/shared/models/database/race.dart]:**
/// The shared [Race] is the Coach-side race configuration entity: it holds
/// the full race spec (location, distance, flow-state machine) and is
/// sync-tracked via Supabase. [RaceRecord] is a lightweight record of a single
/// Assistant timing session: when the recording started and stopped, total
/// duration, and race type. It has no awareness of flow state, location, or
/// distance — those concerns belong to the Coach. The two live in separate
/// databases and must not be merged.
class RaceRecord {
  final int raceId;
  final DateTime date;
  final String name;
  final String type;
  final DateTime? startedAt;
  final bool stopped;
  final Duration? duration;

  RaceRecord({
    required this.raceId,
    required this.date,
    required this.name,
    required this.type,
    this.stopped = true,
    this.startedAt,
    this.duration,
  });

  String get formattedDate => '${date.month}/${date.day}';

  String get formattedName =>
      name.length > 20 ? '${name.substring(0, 17)}...' : name;

  String get formattedTitle => '$formattedName $formattedDate';

  Map<String, dynamic> toMap() {
    return {
      'race_id': raceId,
      'date': date.millisecondsSinceEpoch,
      'name': name,
      'type': type,
      'started_at': startedAt?.millisecondsSinceEpoch,
      'stopped': stopped ? 1 : 0, // Convert boolean to integer for SQLite
      'duration': duration?.inMilliseconds,
    };
  }

  factory RaceRecord.fromMap(Map<String, dynamic> map) {
    return RaceRecord(
      raceId: _convertToInt(map['race_id']),
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      name: map['name'] as String,
      type: map['type'] as String,
      startedAt: map['started_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int)
          : null,
      stopped: map['stopped'] != null
          ? _convertToBool(map['stopped'])
          : true, // Convert to boolean
      duration: map['duration'] != null
          ? Duration(milliseconds: map['duration'] as int)
          : null,
    );
  }

  String encode() {
    return jsonEncode(toMap());
  }

  factory RaceRecord.fromEncodedString(String encodedString, {String? type}) {
    final map = jsonDecode(encodedString);
    if (type != null) {
      map['type'] = type;
    }
    return RaceRecord.fromMap(map);
  }

  /// Helper method to safely convert database value to boolean
  static bool _convertToBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  /// Helper method to safely convert database value to integer
  static int _convertToInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.parse(value);
    if (value is double) return value.toInt();
    throw ArgumentError('Cannot convert $value to int');
  }
}
