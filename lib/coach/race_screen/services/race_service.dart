import '../../../shared/models/database/race.dart';
import '../../../shared/models/database/master_race.dart';
import '../../../shared/models/database/i_master_race_resolver.dart';
import '../../../shared/models/database/team.dart';
import 'i_race_service.dart';
import 'package:intl/intl.dart';

class RaceService implements IRaceService {
  /// Saves race details to the database.
  @override
  Future<void> saveRaceDetails({
    required MasterRace masterRace,
    required Race currentRace,
    required String raceName,
    required String location,
    required DateTime? date,
    required double distance,
    required String unit,
  }) async {
    final updatedRace = currentRace.copyWith(
      raceName: raceName,
      location: location,
      raceDate: date,
      distance: distance,
      distanceUnit: unit,
    );

    await masterRace.updateRace(updatedRace);
    // Note: Teams are now managed separately by RunnersManagementController
  }

  /// Returns true if every team in the race has at least one runner.
  @override
  Future<bool> checkMinimumRunnersLoaded(
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
  @override
  Future<bool> checkSetupComplete({
    required Race race,
    required List<Team> teams,
    required MasterRace masterRace,
    required String name,
    required String location,
    required String date,
    required String distance,
  }) async {
    if (race.flowState != Race.FLOW_SETUP) return true;

    final hasMinimumRunners = await checkMinimumRunnersLoaded(masterRace);

    final hasTeams = teams.isNotEmpty;

    // Check if essential race fields are filled
    final fieldsComplete = name.isNotEmpty &&
        location.isNotEmpty &&
        date.isNotEmpty &&
        distance.isNotEmpty &&
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
