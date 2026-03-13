import 'package:xceleration/coach/merge_conflicts/models/ui_chunk.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';

class TimingDataConverter {
  static List<UIChunk> convertToUIChunks(
      List<TimingChunk> timingChunks, List<RaceRunner> runners) {
    final runnersCopy = List<RaceRunner>.from(runners);
    final uiChunks = <UIChunk>[];
    int startingPlace = 1;
    for (int i = 0; i < timingChunks.length; i++) {
      final chunk = timingChunks[i];
      // Skip chunks without conflicts or chunks with conflicts but no timing data
      if (!chunk.hasConflict ||
          chunk.conflictRecord == null ||
          chunk.timingData.isEmpty) {
        continue;
      }

      final times = chunk.timingData.map((e) => e.time).toList();
      if (times.isEmpty) {
        continue; // Skip if no times (shouldn't happen due to earlier check)
      }

      final uiChunk = UIChunk(
        timingChunkHash: chunk.hashCode,
        times: times,
        allRunners: runnersCopy,
        conflictRecord: chunk.conflictRecord!,
        originalTimingData: chunk.timingData,
        startingPlace: startingPlace,
        chunkId: chunk.id,
      );
      uiChunks.add(uiChunk);
      startingPlace += uiChunk.records.length;
    }
    return uiChunks;
  }
}
