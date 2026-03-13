/// Represents the UI state for a single time entry in a conflict resolution UI
class ConflictTime {
  final String time;
  final bool isOriginallyTBD;
  final String? validationError;

  const ConflictTime({
    required this.time,
    required this.isOriginallyTBD,
    this.validationError,
  });

  ConflictTime copyWith({
    String? time,
    bool? isOriginallyTBD,
    String? validationError,
  }) {
    return ConflictTime(
      time: time ?? this.time,
      isOriginallyTBD: isOriginallyTBD ?? this.isOriginallyTBD,
      validationError: validationError,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConflictTime &&
          runtimeType == other.runtimeType &&
          time == other.time &&
          isOriginallyTBD == other.isOriginallyTBD &&
          validationError == other.validationError;

  @override
  int get hashCode => Object.hash(time, isOriginallyTBD, validationError);
}
