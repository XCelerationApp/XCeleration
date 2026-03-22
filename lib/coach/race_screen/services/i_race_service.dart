import '../../../shared/models/database/master_race.dart';
import '../../../shared/models/database/race.dart';
import '../../../shared/models/database/team.dart';
import '../../../shared/models/database/i_master_race_resolver.dart';

abstract interface class IRaceService {
  Future<void> saveRaceDetails({
    required MasterRace masterRace,
    required Race currentRace,
    required String raceName,
    required String location,
    required DateTime? date,
    required double distance,
    required String unit,
  });

  Future<bool> checkMinimumRunnersLoaded(IMasterRaceResolver masterRace);

  Future<bool> checkSetupComplete({
    required Race race,
    required List<Team> teams,
    required MasterRace masterRace,
    required String name,
    required String location,
    required String date,
    required String distance,
  });
}
