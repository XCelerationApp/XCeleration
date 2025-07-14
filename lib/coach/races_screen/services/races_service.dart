import 'package:flutter/material.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import '../../../shared/models/database/race.dart';
import '../../../core/utils/database_helper.dart';

class RacesService {
  /// Loads all races from the database.
  static Future<List<Race>> loadRaces() async {
    return await DatabaseHelper.instance.getAllRaces();
  }

  /// Creates a new race in the database.
  static Future<int> createRace(Race race) async {
    return await DatabaseHelper.instance.createRace(race);
  }

  /// Updates an existing race in the database.
  static Future<void> updateRace(Race race) async {
    await MasterRace.getInstance(race.raceId!).updateRace(race);
  }

  /// Deletes a race from the database.
  static Future<void> deleteRace(int raceId) async {
    await DatabaseHelper.instance.deleteRace(raceId);
  }

  /// Validates race creation form fields.
  static String? validateName(String name) {
    return name.isEmpty ? 'Please enter a race name' : null;
  }

  static String? validateLocation(String location) {
    return location.isEmpty ? 'Please enter a location' : null;
  }

  static String? validateDate(String dateString) {
    if (dateString.isEmpty) return 'Please select a date';
    try {
      final date = DateTime.parse(dateString);
      if (date.year < 1900) return 'Invalid date';
      return null;
    } catch (e) {
      return 'Invalid date format';
    }
  }

  static String? validateDistance(String distanceString) {
    if (distanceString.isEmpty) return 'Please enter a race distance';
    try {
      final distance = double.parse(distanceString);
      if (distance <= 0) return 'Distance must be greater than 0';
      return null;
    } catch (e) {
      return 'Invalid distance';
    }
  }

  static String? getFirstError({
    required TextEditingController nameController,
    required TextEditingController locationController,
    required TextEditingController dateController,
    required TextEditingController distanceController,
    required List<TextEditingController> teamControllers,
  }) {
    if (nameController.text.isEmpty) {
      return 'Please enter a race name';
    }
    if (locationController.text.isEmpty) {
      return 'Please enter a race location';
    }
    if (dateController.text.isEmpty) {
      return 'Please select a race date';
    } else {
      try {
        final date = DateTime.parse(dateController.text);
        if (date.year < 1900) {
          return 'Invalid date';
        }
      } catch (e) {
        return 'Invalid date format';
      }
    }
    if (distanceController.text.isEmpty) {
      return 'Please enter a race distance';
    } else {
      try {
        final distance = double.parse(distanceController.text);
        if (distance <= 0) {
          return 'Distance must be greater than 0';
        }
      } catch (e) {
        return 'Invalid distance';
      }
    }
    List<String> teams = teamControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    if (teams.isEmpty) {
      return 'Please add at least one team';
    }
    return null;
  }
}
