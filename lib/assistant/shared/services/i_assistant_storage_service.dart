import 'package:xceleration/assistant/shared/models/bib_record.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

abstract interface class IAssistantStorageService {
  // Race Methods

  Future<Result<void>> saveNewRace(RaceRecord race);

  Future<Result<void>> updateRace(RaceRecord race);

  Future<Result<void>> updateRaceDuration(
      int raceId, String type, Duration? time);

  Future<Result<void>> updateRaceStartTime(
      int raceId, String type, DateTime? startedAt);

  Future<Result<void>> updateRaceStatus(int raceId, String type, bool stopped);

  Future<Result<List<RaceRecord>>> getRecentRaces(String type,
      {Duration? since});

  Future<Result<List<RaceRecord>>> getRaces(String type);

  Future<Result<RaceRecord?>> getRace(int raceId, String type);

  Future<Result<void>> deleteRace(int raceId, String type);

  Future<Result<void>> deleteOldRaces({Duration? olderThan});

  // Chunk Methods

  Future<Result<void>> saveChunk(int raceId, TimingChunk chunk);

  Future<Result<TimingChunk?>> getChunk(int raceId, int chunkId);

  Future<Result<String?>> getChunkTimingData(int raceId, int chunkId);

  Future<Result<List<TimingChunk>>> getChunks(int raceId);

  Future<Result<void>> deleteChunk(int raceId, int chunkId);

  Future<Result<void>> deleteChunks(int raceId);

  Future<Result<void>> saveChunkConflict(
      int raceId, int chunkId, TimingDatum conflictRecord);

  Future<Result<void>> updateChunkConflict(
      String chunkId, TimingDatum? conflictRecord);

  Future<Result<String?>> getChunkConflict(String chunkId);

  Future<Result<void>> saveChunkTimingData(
      String chunkId, List<String> encodedRecords);

  Future<Result<void>> updateChunkTimingData(
      int raceId, int chunkId, List<TimingDatum> timingData);

  Future<Result<void>> addLoggedTimingDatum(
      int raceId, int chunkId, TimingDatum datum);

  // Runner Methods

  Future<Result<void>> saveRunner(Runner runner);

  Future<Result<void>> saveRunners(int raceId, List<Runner> runners);

  Future<Result<Runner?>> getRunner(int raceId, String bibNumber);

  Future<Result<List<Runner>>> getRunners(int raceId);

  Future<Result<void>> updateRunner(Runner runner);

  Future<Result<void>> deleteRunner(int raceId, String bibNumber);

  Future<Result<void>> deleteRunners(int raceId);

  // Bib Record Methods

  Future<Result<void>> saveBibRecord(BibRecord bibRecord);

  Future<Result<void>> saveBibRecords(int raceId, List<BibRecord> bibRecords);

  Future<Result<void>> addBibRecord(int raceId, int bibId, String bibNumber);

  Future<Result<void>> removeBibRecord(int raceId, int bibId);

  Future<Result<void>> updateBibRecordValue(
      int raceId, int bibId, String bibNumber);

  Future<Result<BibRecord?>> getBibRecord(int raceId, int bibId);

  Future<Result<List<BibRecord>>> getBibRecords(int raceId);

  Future<Result<void>> updateBibRecord(BibRecord bibRecord);

  Future<Result<void>> deleteBibRecord(int raceId, int bibId);

  Future<Result<void>> deleteBibRecords(int raceId);

  Future<Result<int>> getNextBibId(int raceId);
}
