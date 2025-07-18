import 'package:xceleration/core/utils/enums.dart';

class Conflict {
  final ConflictType type;
  int offBy;

  Conflict({
    required this.type,
    this.offBy = 1,
  });

  @override
  String toString() {
    return 'Conflict(type: $type, offBy: $offBy)';
  }

  String encode() {
    return '$type,$offBy';
  }

  factory Conflict.decode(String encoded) {
    final parts = encoded.split(',');
    return Conflict(type: ConflictType.values[int.parse(parts[0])], offBy: int.parse(parts[1]));
  }
}