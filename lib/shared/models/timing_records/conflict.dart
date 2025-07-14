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
}