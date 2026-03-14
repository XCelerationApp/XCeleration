import '../../shared/models/database/base_models.dart';

abstract interface class IResultsRepository {
  Future<void> saveRaceResults(int raceId, List<RaceResult> results);
  Future<void> addRaceResult(RaceResult result);
  Future<RaceResult?> getRaceResult(RaceResult raceResult);
  Future<List<RaceResult>> getRaceResults(int raceId);
  Future<void> updateRaceResult(RaceResult raceResult);
  Future<void> deleteRaceResult(RaceResult raceResult);
}
