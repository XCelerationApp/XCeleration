import 'package:flutter/material.dart';
import '../../../shared/models/race.dart';
import '../../../utils/database_helper.dart';
import 'package:intl/intl.dart';
import '../../runners_management_screen/screen/runners_management_screen.dart';

class RaceService {
  /// Saves race details to the database.
  static Future<void> saveRaceDetails({
    required int raceId,
    required TextEditingController locationController,
    required TextEditingController dateController,
    required TextEditingController distanceController,
    required TextEditingController unitController,
    required List<TextEditingController> teamControllers,
    required List<Color> teamColors,
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
      distance = (parsedDistance != null && parsedDistance > 0) ? parsedDistance : 0;
    }
    // Update the race in database
    await DatabaseHelper.instance.updateRaceField(raceId, 'location', locationController.text);
    await DatabaseHelper.instance.updateRaceField(raceId, 'raceDate', date?.toIso8601String());
    await DatabaseHelper.instance.updateRaceField(raceId, 'distance', distance);
    await DatabaseHelper.instance.updateRaceField(raceId, 'distanceUnit', unitController.text);
    await saveTeamData(
      race: null, // Not needed for DB update
      teamControllers: teamControllers,
      teamColors: teamColors,
    );
  }

  /// Checks if all requirements are met to advance to setup_complete.
  static Future<bool> checkSetupComplete({
    required Race? race,
    required int raceId,
    required TextEditingController nameController,
    required TextEditingController locationController,
    required TextEditingController dateController,
    required TextEditingController distanceController,
    required List<TextEditingController> teamControllers,
  }) async {
    if (race?.flowState != Race.FLOW_SETUP) return false;
    // Check for minimum runners
    final hasMinimumRunners = await RunnersManagementScreen.checkMinimumRunnersLoaded(raceId);
    // Check if essential race fields are filled
    final fieldsComplete =
        nameController.text.isNotEmpty &&
        locationController.text.isNotEmpty &&
        dateController.text.isNotEmpty &&
        distanceController.text.isNotEmpty &&
        teamControllers.where((controller) => controller.text.isNotEmpty).isNotEmpty;
    return hasMinimumRunners && fieldsComplete;
  }

  /// Saves team data to the database.
  static Future<void> saveTeamData({
    required Race? race,
    required List<TextEditingController> teamControllers,
    required List<Color> teamColors,
  }) async {
    // Compose teams and colors
    final teams = teamControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    final colors = teamColors.map((color) => color.toARGB32()).toList();
    // Use raceId if available, otherwise skip
    final int? raceId = race?.raceId;
    if (raceId != null) {
      await DatabaseHelper.instance.updateRaceField(raceId, 'teams', teams);
      await DatabaseHelper.instance.updateRaceField(raceId, 'teamColors', colors);
    }
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