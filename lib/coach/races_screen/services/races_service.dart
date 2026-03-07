import 'package:flutter/material.dart';
import 'package:xceleration/core/services/auth_service.dart';
import 'package:xceleration/core/utils/database_helper.dart';
import 'package:xceleration/core/utils/i_database_helper.dart';
import '../../../shared/models/database/race.dart';

abstract interface class IRacesService {
  Future<List<Race>> loadRaces();
  Future<int> createRace(Race race);
  Future<void> updateRace(Race race);
  Future<void> deleteRace(int raceId);
  String? validateName(String name);
  String? validateLocation(String location);
  String? validateDate(String dateString);
  String? validateDistance(String distanceString);
  String? getFirstError({
    required TextEditingController nameController,
    required TextEditingController locationController,
    required TextEditingController dateController,
    required TextEditingController distanceController,
    required List<TextEditingController> teamControllers,
  });
}

class RacesService implements IRacesService {
  final IDatabaseHelper _db;
  final String? Function() _currentUserId;

  RacesService({
    IDatabaseHelper? db,
    String? Function()? currentUserId,
  })  : _db = db ?? DatabaseHelper.instance,
        _currentUserId =
            currentUserId ?? (() => AuthService.instance.currentUserId);

  /// Loads all races from the database.
  @override
  Future<List<Race>> loadRaces() async {
    return await _db.getAllRaces();
  }

  /// Creates a new race in the database.
  @override
  Future<int> createRace(Race race) async {
    final ownerId = _currentUserId();
    final raceWithOwner = race.copyWith(ownerUserId: ownerId);
    return await _db.createRace(raceWithOwner);
  }

  /// Updates an existing race in the database.
  @override
  Future<void> updateRace(Race race) async {
    await _db.updateRace(race);
  }

  /// Deletes a race from the database.
  @override
  Future<void> deleteRace(int raceId) async {
    await _db.deleteRace(raceId);
  }

  /// Validates race creation form fields.
  @override
  String? validateName(String name) {
    return name.isEmpty ? 'Please enter a race name' : null;
  }

  @override
  String? validateLocation(String location) {
    return location.isEmpty ? 'Please enter a location' : null;
  }

  @override
  String? validateDate(String dateString) {
    if (dateString.isEmpty) return 'Please select a date';
    try {
      final date = DateTime.parse(dateString);
      if (date.year < 1900) return 'Invalid date';
      return null;
    } catch (e) {
      return 'Invalid date format';
    }
  }

  @override
  String? validateDistance(String distanceString) {
    if (distanceString.isEmpty) return 'Please enter a race distance';
    try {
      final distance = double.parse(distanceString);
      if (distance <= 0) return 'Distance must be greater than 0';
      return null;
    } catch (e) {
      return 'Invalid distance';
    }
  }

  @override
  String? getFirstError({
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
