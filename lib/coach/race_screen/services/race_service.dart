import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import '../../../shared/models/race.dart';
import '../../../core/utils/database_helper.dart';
import 'package:intl/intl.dart';
import '../../runners_management_screen/screen/runners_management_screen.dart';

class RaceService {
  /// Saves race details to the database.
  static Future<void> saveRaceDetails({
    required int raceId,
    required TextEditingController nameController,
    required TextEditingController locationController,
    required TextEditingController dateController,
    required TextEditingController distanceController,
    required TextEditingController unitController,
  }) async {
    // First, always update the race name
    await DatabaseHelper.instance
        .updateRaceField(raceId, 'raceName', nameController.text.trim());

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
    // Update the race in database
    await DatabaseHelper.instance
        .updateRaceField(raceId, 'location', locationController.text);
    await DatabaseHelper.instance
        .updateRaceField(raceId, 'raceDate', date?.toIso8601String());
    await DatabaseHelper.instance.updateRaceField(raceId, 'distance', distance);
    await DatabaseHelper.instance
        .updateRaceField(raceId, 'distanceUnit', unitController.text);
    // Note: Teams are now managed separately by RunnersManagementController
  }

  /// Checks if all requirements are met to advance to setup_complete.
  static Future<bool> checkSetupComplete({
    required Race? race,
    required int raceId,
    required TextEditingController nameController,
    required TextEditingController locationController,
    required TextEditingController dateController,
    required TextEditingController distanceController,
  }) async {
    if (race?.flowState != Race.FLOW_SETUP) return true;

    // Check for minimum runners
    final hasMinimumRunners =
        await TeamsAndRunnersManagementWidget.checkMinimumRunnersLoaded(raceId);

    // Get current race data to check for teams
    final currentRace = await DatabaseHelper.instance.getRaceById(raceId);
    final hasTeams = currentRace != null && currentRace.teams.isNotEmpty;

    // Check if essential race fields are filled
    final fieldsComplete = nameController.text.isNotEmpty &&
        locationController.text.isNotEmpty &&
        dateController.text.isNotEmpty &&
        distanceController.text.isNotEmpty &&
        hasTeams;

    Logger.d(
        'hasMinimumRunners: $hasMinimumRunners, fieldsComplete: $fieldsComplete, hasTeams: $hasTeams');
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
