import 'package:flutter/material.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/auth_service.dart';
import 'package:xceleration/core/utils/i_database_helper.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import '../../../shared/models/database/race.dart';

class RacesService {
  final IDatabaseHelper _db;
  final String? Function() _currentUserId;

  RacesService({
    required IDatabaseHelper db,
    String? Function()? currentUserId,
  })  : _db = db,
        _currentUserId =
            currentUserId ?? (() => AuthService.instance.currentUserId);

  /// Loads all races from the database.
  Future<Result<List<Race>>> loadRaces() async {
    try {
      final races = await _db.getAllRaces();
      return Success(races);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not load races. Please try again.',
        originalException: e,
      ));
    }
  }

  /// Creates a new race in the database.
  Future<Result<int>> createRace(Race race) async {
    try {
      final ownerId = _currentUserId();
      final raceWithOwner = race.copyWith(ownerUserId: ownerId);
      final id = await _db.createRace(raceWithOwner);
      return Success(id);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not create race. Please try again.',
        originalException: e,
      ));
    }
  }

  /// Updates an existing race in the database.
  Future<Result<void>> updateRace(Race race) async {
    try {
      await MasterRace.getInstance(race.raceId!).updateRace(race);
      return const Success(null);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not update race. Please try again.',
        originalException: e,
      ));
    }
  }

  /// Deletes a race from the database.
  Future<Result<void>> deleteRace(int raceId) async {
    try {
      await _db.deleteRace(raceId);
      return const Success(null);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not delete race. Please try again.',
        originalException: e,
      ));
    }
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
