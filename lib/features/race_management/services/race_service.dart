import '../../../utils/database_helper.dart';
import '../../../core/utils/logger.dart';
import '../../../core/services/event_bus.dart';
import '../models/race_model.dart';
import '../../../shared/constants/app_constants.dart' as constants;

/// Consolidated service for all race management operations
class RaceService {
  final DatabaseHelper _databaseHelper;
  final EventBus _eventBus;

  RaceService({
    DatabaseHelper? databaseHelper,
    EventBus? eventBus,
  })  : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
        _eventBus = eventBus ?? EventBus.instance;

  /// Create a new race
  Future<int> createRace(RaceModel race) async {
    try {
      final raceId =
          await _databaseHelper.insertRace(_convertToLegacyRace(race));
      Logger.d('Created race with ID: $raceId');

      _eventBus.fire(constants.EventTypes.raceCreated, {
        'raceId': raceId,
        'race': race.copyWith(raceId: raceId),
      });

      return raceId;
    } catch (e) {
      Logger.e('Error creating race', error: e);
      rethrow;
    }
  }

  /// Update an existing race
  Future<void> updateRace(RaceModel race) async {
    try {
      await _databaseHelper.updateRace(_convertToLegacyRace(race));
      Logger.d('Updated race: ${race.raceId}');

      _eventBus.fire(constants.EventTypes.raceUpdated, {
        'raceId': race.raceId,
        'race': race,
      });
    } catch (e) {
      Logger.e('Error updating race', error: e);
      rethrow;
    }
  }

  /// Delete a race
  Future<void> deleteRace(int raceId) async {
    try {
      await _databaseHelper.deleteRace(raceId);
      Logger.d('Deleted race: $raceId');

      _eventBus.fire(constants.EventTypes.raceDeleted, {
        'raceId': raceId,
      });
    } catch (e) {
      Logger.e('Error deleting race', error: e);
      rethrow;
    }
  }

  /// Get a race by ID
  Future<RaceModel?> getRaceById(int raceId) async {
    try {
      final legacyRace = await _databaseHelper.getRaceById(raceId);
      if (legacyRace == null) return null;

      // Load additional data
      final runners = await _databaseHelper.getRaceRunners(raceId);
      final statistics = await _calculateRaceStatistics(raceId);

      return _convertFromLegacyRace(legacyRace, runners, statistics);
    } catch (e) {
      Logger.e('Error getting race by ID', error: e);
      return null;
    }
  }

  /// Get all races
  Future<List<RaceModel>> getAllRaces() async {
    try {
      final legacyRaces = await _databaseHelper.getAllRaces();
      final races = <RaceModel>[];

      for (final legacyRace in legacyRaces) {
        final runners = await _databaseHelper.getRaceRunners(legacyRace.raceId);
        final statistics = await _calculateRaceStatistics(legacyRace.raceId);
        races.add(_convertFromLegacyRace(legacyRace, runners, statistics));
      }

      return races;
    } catch (e) {
      Logger.e('Error getting all races', error: e);
      return [];
    }
  }

  /// Update race flow state
  Future<void> updateRaceFlowState(int raceId, String newFlowState) async {
    try {
      await _databaseHelper.updateRaceFlowState(raceId, newFlowState);
      Logger.d('Updated race flow state: $raceId -> $newFlowState');

      _eventBus.fire(constants.EventTypes.raceFlowStateChanged, {
        'raceId': raceId,
        'newState': newFlowState,
      });
    } catch (e) {
      Logger.e('Error updating race flow state', error: e);
      rethrow;
    }
  }

  /// Add runners to a race
  Future<void> addRunnersToRace(int raceId, List<RunnerModel> runners) async {
    try {
      for (final runner in runners) {
        await _databaseHelper.insertRaceRunner(_convertToLegacyRunner(runner));
      }

      Logger.d('Added ${runners.length} runners to race $raceId');

      _eventBus.fire(constants.EventTypes.runnersAdded, {
        'raceId': raceId,
        'runners': runners,
      });
    } catch (e) {
      Logger.e('Error adding runners to race', error: e);
      rethrow;
    }
  }

  /// Remove a runner from a race
  Future<void> removeRunnerFromRace(int raceId, String bibNumber) async {
    try {
      await _databaseHelper.deleteRaceRunner(raceId, bibNumber);
      Logger.d('Removed runner with bib $bibNumber from race $raceId');

      _eventBus.fire(constants.EventTypes.runnerRemoved, {
        'raceId': raceId,
        'bibNumber': bibNumber,
      });
    } catch (e) {
      Logger.e('Error removing runner from race', error: e);
      rethrow;
    }
  }

  /// Get race results
  Future<List<dynamic>> getRaceResults(int raceId) async {
    try {
      return await _databaseHelper.getRaceResults(raceId);
    } catch (e) {
      Logger.e('Error getting race results', error: e);
      return [];
    }
  }

  /// Calculate race statistics
  Future<RaceStatistics> _calculateRaceStatistics(int raceId) async {
    try {
      final runners = await _databaseHelper.getRaceRunners(raceId);
      final results = await _databaseHelper.getRaceResults(raceId);

      // Calculate basic statistics
      final totalRunners = runners.length;
      final completedRunners = results.length;

      // Get unique teams
      final teams = runners.map((r) => r.school).toSet().toList();
      final totalTeams = teams.length;

      // Calculate timing statistics from results
      Duration? fastestTime;
      Duration? averageTime;

      if (results.isNotEmpty) {
        // This would need to be implemented based on your results structure
        // For now, returning basic statistics
      }

      return RaceStatistics(
        totalRunners: totalRunners,
        totalTeams: totalTeams,
        completedRunners: completedRunners,
        fastestTime: fastestTime,
        averageTime: averageTime,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      Logger.e('Error calculating race statistics', error: e);
      return const RaceStatistics();
    }
  }

  /// Validation methods
  static List<String> validateRaceData(RaceModel race) {
    return race.validationErrors;
  }

  static String? validateRaceName(String name) {
    if (name.trim().isEmpty) return 'Race name is required';
    if (name.length > 100) return 'Race name is too long';
    return null;
  }

  static String? validateLocation(String location) {
    if (location.trim().isEmpty) return 'Location is required';
    if (location.length > 200) return 'Location is too long';
    return null;
  }

  static String? validateDistance(String distanceStr) {
    if (distanceStr.trim().isEmpty) return 'Distance is required';

    final distance = double.tryParse(distanceStr);
    if (distance == null) return 'Invalid distance format';
    if (distance <= 0) return 'Distance must be greater than 0';
    if (distance > 1000) return 'Distance seems too large';

    return null;
  }

  static String? validateDate(String dateStr) {
    if (dateStr.trim().isEmpty) return 'Date is required';

    try {
      final date = DateTime.parse(dateStr);
      if (date.year < 1900 || date.year > 2100) {
        return 'Invalid date year';
      }
      return null;
    } catch (e) {
      return 'Invalid date format';
    }
  }

  /// Helper methods to convert between new and legacy models
  /// These are temporary while we transition the database layer

  dynamic _convertToLegacyRace(RaceModel race) {
    // This would convert to the existing Race class format
    // Implementation depends on your current Race class structure
    return race.toJson(forDatabase: true);
  }

  RaceModel _convertFromLegacyRace(
      dynamic legacyRace, List<dynamic> runners, RaceStatistics statistics) {
    // Convert legacy race and runners to new model
    final runnerModels = runners
        .map((r) => RunnerModel(
              name: r.name ?? '',
              school: r.school ?? '',
              grade: r.grade ?? '',
              bib: r.bib ?? '',
              raceId: legacyRace.raceId,
            ))
        .toList();

    return RaceModel(
      raceId: legacyRace.raceId,
      raceName: legacyRace.raceName ?? '',
      raceDate: legacyRace.raceDate,
      location: legacyRace.location ?? '',
      distance: legacyRace.distance?.toDouble() ?? 0.0,
      distanceUnit: legacyRace.distanceUnit ?? 'mi',
      teamColors: legacyRace.teamColors ?? [],
      teams: legacyRace.teams ?? [],
      flowState: legacyRace.flowState ?? RaceModel.FLOW_SETUP,
      runners: runnerModels,
      statistics: statistics,
    );
  }

  dynamic _convertToLegacyRunner(RunnerModel runner) {
    // Convert to existing runner format for database
    return runner.toJson();
  }

  /// Utility methods

  /// Check if a race name already exists
  Future<bool> raceNameExists(String name, {int? excludeRaceId}) async {
    try {
      final races = await getAllRaces();
      return races.any((race) =>
          race.raceName.toLowerCase() == name.toLowerCase() &&
          race.raceId != excludeRaceId);
    } catch (e) {
      Logger.e('Error checking race name existence', error: e);
      return false;
    }
  }

  /// Get races by flow state
  Future<List<RaceModel>> getRacesByFlowState(String flowState) async {
    try {
      final allRaces = await getAllRaces();
      return allRaces.where((race) => race.flowState == flowState).toList();
    } catch (e) {
      Logger.e('Error getting races by flow state', error: e);
      return [];
    }
  }

  /// Get active races (not finished)
  Future<List<RaceModel>> getActiveRaces() async {
    try {
      final allRaces = await getAllRaces();
      return allRaces
          .where((race) => race.flowState != RaceModel.FLOW_FINISHED)
          .toList();
    } catch (e) {
      Logger.e('Error getting active races', error: e);
      return [];
    }
  }
}
