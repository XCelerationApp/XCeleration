import 'package:xceleration/coach/merge_conflicts/models/ui_chunk.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';

/// Converts [TimingChunk] lists into [UIChunk] lists for the Coach merge-conflict
/// resolution screen.
///
/// This is intentionally separate from [RaceTimerDataConverter]
/// (lib/assistant/race_timer/utils/timing_data_converter.dart), which handles
/// live-timing conversion for the Assistant role. The two converters operate on
/// different UIChunk types, use different conflict-resolution strategies, and must
/// not be merged.
class CoachTimingDataConverter {
  /// [recordedTimes] holds, by chunk id, the times the Timer recorded in each
  /// missing-time chunk; any other time there was entered by the coach.
  static List<UIChunk> convertToUIChunks(
      List<TimingChunk> timingChunks, List<RaceRunner> runners,
      {Map<int, Set<String>>? recordedTimes}) {
    final runnersCopy = List<RaceRunner>.from(runners);
    final uiChunks = <UIChunk>[];
    int startingPlace = 1;
    for (int i = 0; i < timingChunks.length; i++) {
      final chunk = timingChunks[i];
      final conflictType = chunk.conflictRecord?.conflict?.type;
      // Show every conflict chunk that has something to resolve. A
      // missing-time chunk can have no times at all (the Timer pressed
      // "missing time" straight after a confirmation) and must still be shown,
      // or its conflict could never be resolved.
      final isShown = chunk.hasConflict &&
          (chunk.timingData.isNotEmpty ||
              (conflictType == ConflictType.missingTime &&
                  chunk.conflictRecord!.conflict!.offBy > 0));
      if (!isShown) {
        // Hidden chunks still hold finishers: consume their places and
        // runners so later chunks line up with the right runners.
        final count = chunk.recordCount.clamp(0, runnersCopy.length);
        runnersCopy.removeRange(0, count);
        startingPlace += chunk.recordCount < 0 ? 0 : chunk.recordCount;
        continue;
      }

      final times = chunk.timingData.map((e) => e.time).toList();

      final uiChunk = UIChunk(
        timingChunkHash: chunk.hashCode,
        times: times,
        allRunners: runnersCopy,
        conflictRecord: chunk.conflictRecord!,
        originalTimingData: chunk.timingData,
        startingPlace: startingPlace,
        chunkId: chunk.id,
        recordedTimes: recordedTimes?[chunk.id],
      );
      uiChunks.add(uiChunk);
      // Count finishers, not rows: an extra time is a row without a place.
      startingPlace += chunk.recordCount < 0 ? 0 : chunk.recordCount;
    }
    return uiChunks;
  }
}
