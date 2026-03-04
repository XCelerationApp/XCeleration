import 'package:xceleration/core/result.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/services/race_results_service.dart';

abstract interface class IRaceResultsService {
  Future<Result<RaceResultsData>> calculateCompleteRaceResults(
      MasterRace masterRace);
}
