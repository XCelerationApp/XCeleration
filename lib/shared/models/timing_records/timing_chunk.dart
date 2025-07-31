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

/// Splits a list of [TimingDatum]s into a single [TimingChunk] in a list.
/// If you want to split by some logic (e.g., by conflict), you can modify this function.
List<TimingChunk> timingChunksFromTimingData(List<TimingDatum> timingData) {
  if (timingData.isEmpty) return [];
  List<TimingChunk> chunks = [];
  List<TimingDatum> currentTimingData = [];

  for (final timingDatum in timingData) {
    if (timingDatum.conflict != null) {
      // When a conflict is found, create a chunk with the current timing data and this conflict
      chunks.add(TimingChunk(
        timingData: List<TimingDatum>.from(currentTimingData),
        conflictRecord: timingDatum,
      ));
      currentTimingData.clear();
    } else {
      currentTimingData.add(timingDatum);
    }
  }

  // If there is any remaining timing data without a conflict, add it as a chunk
  if (currentTimingData.isNotEmpty) {
    chunks.add(TimingChunk(
      timingData: List<TimingDatum>.from(currentTimingData),
      conflictRecord: null,
    ));
  }

  return chunks;
}

