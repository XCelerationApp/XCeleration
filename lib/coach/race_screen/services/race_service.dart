import 'package:flutter/material.dart';
import '../../../shared/models/database/race.dart';
import '../../../shared/models/database/master_race.dart';
import '../../../shared/models/database/i_master_race_resolver.dart';
import '../../../shared/models/database/team.dart';
import 'package:intl/intl.dart';

class RaceService {
  /// Saves race details to the database.
  static Future<void> saveRaceDetails({
    required MasterRace masterRace,
    required TextEditingController nameController,
    required TextEditingController locationController,
    required TextEditingController dateController,
    required TextEditingController distanceController,
    required TextEditingController unitController,
  }) async {
    // Parse date
    DateTime? date;
    if (dateController.text.isNotEmpty) {
      date = DateTime.tryParse(dateController.text);
    }
    // Parse distance
    double distance = 0;
    if (distanceController.text.isNotEmpty) {
      final parsedDistance = double.tryParse(distanceController.text);
      distance =
          (parsedDistance != null && parsedDistance > 0) ? parsedDistance : 0;
    }
    // Preserve existing race fields (like flowState, ownerUserId, etc.)
    // and only update the edited fields
    final currentRace = await masterRace.race;
    final updatedRace = currentRace.copyWith(
      raceName: nameController.text.trim(),
      location: locationController.text,
      raceDate: date,
      distance: distance,
      distanceUnit: unitController.text,
    );

    await masterRace.updateRace(updatedRace);
    // Note: Teams are now managed separately by RunnersManagementController
  }

  /// Returns true if every team in the race has at least one runner.
  static Future<bool> checkMinimumRunnersLoaded(
      IMasterRaceResolver masterRace) async {
    final teamsList = await masterRace.teams;
    if (teamsList.isEmpty) return false;

    final raceRunnersList = await masterRace.raceRunners;
    final teamsWithRunners =
        raceRunnersList.map((rr) => rr.team.teamId).toSet();

    for (final team in teamsList) {
      if (!teamsWithRunners.contains(team.teamId)) return false;
    }
    return true;
  }

  /// Checks if all requirements are met to advance to setup_complete.
  ///
  /// Accepts already-loaded [race] and [teams] to avoid redundant DB reads.
  /// [masterRace] is still needed to check the minimum runners count.
  static Future<bool> checkSetupComplete({
    required Race race,
    required List<Team> teams,
    required MasterRace masterRace,
    required TextEditingController nameController,
    required TextEditingController locationController,
    required TextEditingController dateController,
    required TextEditingController distanceController,
  }) async {
    if (race.flowState != Race.FLOW_SETUP) return true;

    final hasMinimumRunners = await checkMinimumRunnersLoaded(masterRace);

    final hasTeams = teams.isNotEmpty;

    // Check if essential race fields are filled
    final fieldsComplete = nameController.text.isNotEmpty &&
        locationController.text.isNotEmpty &&
        dateController.text.isNotEmpty &&
        distanceController.text.isNotEmpty &&
        hasTeams;
    return hasMinimumRunners && fieldsComplete;
  }

  /// Validation helpers for form fields.
  static String? validateName(String name) {
    return name.isEmpty ? 'Please enter a race name' : null;
  }

  static String? validateLocation(String location) {
    return location.isEmpty ? 'Please enter a location' : null;
  }

  static String? validateDate(String dateString) {
    if (dateString.isEmpty) return 'Please enter a date';
    try {
      DateFormat('yyyy-MM-dd').parseStrict(dateString);
      return null;
    } catch (e) {
      return 'Please enter a valid date (YYYY-MM-DD)';
    }
  }

  static String? validateDistance(String distanceString) {
    if (distanceString.isEmpty) return 'Please enter a distance';
    try {
      final distance = double.parse(distanceString);
      if (distance <= 0) return 'Distance must be greater than 0';
      return null;
    } catch (e) {
      return 'Please enter a valid number';
    }
  }
}
