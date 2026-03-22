import 'package:xceleration/core/result.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race_result.dart';
import 'package:xceleration/shared/services/race_results_service.dart';
import 'package:xceleration/coach/race_results/model/results_record.dart';

abstract interface class IRaceResultsService {
  Future<Result<RaceResultsData>> calculateCompleteRaceResults(
      MasterRace masterRace);

  List<ResultsRecord> convertToResultsRecords(
    List<RaceResult> raceResults, {
    double? raceDistance,
    String? distanceUnit,
  });
}
