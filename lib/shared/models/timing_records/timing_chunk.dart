import 'timing_datum.dart';
import 'package:xceleration/core/utils/enums.dart';

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
  int get recordCount {
    int count = timingData.length;
    if (hasConflict && conflictRecord!.conflict != null) {
      final conflictType = conflictRecord!.conflict!.type;
      final offBy = conflictRecord!.conflict!.offBy;

      if (conflictType == ConflictType.missingTime) {
        count += offBy; // Add missing timing events
      } else if (conflictType == ConflictType.extraTime) {
        count -= offBy; // Subtract extra timing events
      }
      // For confirmRunner and other types, don't modify count
    }
    return count;
  }

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
    // The encoding format is: "t1,t2,t3 <conflict-encoded>"
    // where conflict-encoded itself contains spaces (e.g., "CR 1 3.60").
    // So we must split only on the first space.
    final int firstSpaceIndex = encoded.indexOf(' ');
    final String timesPart;
    final String? conflictPart;

    if (firstSpaceIndex == -1) {
      timesPart = encoded;
      conflictPart = null;
    } else {
      timesPart = encoded.substring(0, firstSpaceIndex);
      final String remainder = encoded.substring(firstSpaceIndex + 1);
      // If the remainder is empty, treat as no conflict
      conflictPart = remainder.trim().isEmpty ? null : remainder;
    }

    final List<TimingDatum> timingData = timesPart.isEmpty
        ? []
        : timesPart
            .split(',')
            .where((s) => s.isNotEmpty)
            .map((datum) => TimingDatum.fromEncodedString(datum))
            .toList();

    final TimingDatum? conflictRecord = conflictPart == null
        ? null
        : TimingDatum.fromEncodedString(conflictPart);

    return TimingChunk(
      conflictRecord: conflictRecord,
      timingData: timingData,
    );
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
