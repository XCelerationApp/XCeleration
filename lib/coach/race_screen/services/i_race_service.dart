import 'package:flutter/material.dart';
import '../../../shared/models/database/master_race.dart';
import '../../../shared/models/database/race.dart';
import '../../../shared/models/database/team.dart';
import '../../../shared/models/database/i_master_race_resolver.dart';

// TODO(XCE-409): Remove TextEditingController params and the Flutter import
// once RaceService is decoupled from UI types.
abstract interface class IRaceService {
  Future<void> saveRaceDetails({
    required MasterRace masterRace,
    required TextEditingController nameController,
    required TextEditingController locationController,
    required TextEditingController dateController,
    required TextEditingController distanceController,
    required TextEditingController unitController,
  });

  Future<bool> checkMinimumRunnersLoaded(IMasterRaceResolver masterRace);

  Future<bool> checkSetupComplete({
    required Race race,
    required List<Team> teams,
    required MasterRace masterRace,
    required TextEditingController nameController,
    required TextEditingController locationController,
    required TextEditingController dateController,
    required TextEditingController distanceController,
  });
}
