import 'timing_datum.dart';

class TimingChunk {
  TimingDatum? conflictRecord;
  final List<TimingDatum> timingData;

  TimingChunk({
    this.conflictRecord,
    required this.timingData,
  }) {
    if (conflictRecord != null && conflictRecord!.conflict == null) {
      throw Exception('Conflict record must have a conflict');
    }
  }

  // Computed properties
  bool get hasConflict => conflictRecord != null;
  bool get isEmpty => timingData.isEmpty && !hasConflict;
  int get recordCount => timingData.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimingChunk &&
          runtimeType == other.runtimeType &&
          conflictRecord == other.conflictRecord &&
          _listEquals(timingData, other.timingData);

  @override
  int get hashCode => Object.hash(
        conflictRecord,
        Object.hashAll(timingData),
      );

  // Helper for list equality
  bool _listEquals(List<TimingDatum> a, List<TimingDatum> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String encode() {
    return '${timingData.map((e) => e.time).join(',')} ${hasConflict ? conflictRecord!.encode() : ''}';
  }

  factory TimingChunk.decode(String encoded) {
    final parts = encoded.split(' ');
    return TimingChunk(
        conflictRecord:
            parts.length > 1 ? TimingDatum.fromEncodedString(parts[1]) : null,
        timingData: parts[0]
            .split(',')
            .map((datum) => TimingDatum.fromEncodedString(datum))
            .toList());
  }
}
