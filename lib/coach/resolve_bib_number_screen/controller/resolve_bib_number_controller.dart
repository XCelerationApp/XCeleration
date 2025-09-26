import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/database/race_participant.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../shared/models/database/master_race.dart';
import '../../../shared/models/database/team.dart';

class ResolveBibNumberController with ChangeNotifier {
  late final MasterRace masterRace;
  List<RaceRunner> searchResults = [];
  final TextEditingController searchController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController gradeController = TextEditingController();
  final TextEditingController teamController = TextEditingController();
  final TextEditingController bibController = TextEditingController();
  bool showCreateNew = false;
  final List<RaceRunner> raceRunners;
  final int raceId;
  final Function(RaceRunner) onComplete;
  final RaceRunner raceRunner;

  BuildContext? _context;

  ResolveBibNumberController({
    required this.raceRunners,
    required this.raceId,
    required this.onComplete,
    required this.raceRunner,
  }) {
    masterRace = MasterRace.getInstance(raceId);

    // Listen to changes from MasterRace
    masterRace.addListener(() {
      notifyListeners();
    });
  }

  void setContext(BuildContext context) {
    _context = context;
  }

  BuildContext get context {
    assert(_context != null,
        'Context not set in ResolveBibNumberController. Call setContext() first.');
    return _context!;
  }

  /// Get all teams (cached by MasterRace)
  Future<List<Team>> get teams => masterRace.teams;

  Future<void> searchRunners(String query) async {
    Logger.d('Searching runners...');
    Logger.d('Query: $query');
    Logger.d('Race ID: $raceId');

    // Get already recorded runners for this race (runners that already have results)
    final recordedBibs =
        raceRunners.map((raceRunner) => raceRunner.runner.bibNumber).toSet();

    Logger.d('Already recorded bibs: ${recordedBibs.join(', ')}');

    List<RaceRunner> filteredRaceRunners;
    if (query.isEmpty) {
      // Get all race runners
      filteredRaceRunners = await masterRace.raceRunners;
    } else {
      // Search race runners by query
      await masterRace.searchRaceRunners(query);
      filteredRaceRunners = (await masterRace.filteredSearchResults)
          .values
          .expand((list) => list)
          .toList();
    }

    // Filter out runners that have already been recorded
    searchResults = filteredRaceRunners
        .where(
            (raceRunner) => !recordedBibs.contains(raceRunner.runner.bibNumber))
        .toList();

    notifyListeners();
    Logger.d('Filtered search results');
  }

  Future<void> createNewRunner() async {
    if (nameController.text.isEmpty ||
        gradeController.text.isEmpty ||
        teamController.text.isEmpty ||
        bibController.text.isEmpty) {
      DialogUtils.showErrorDialog(context,
          message:
              'Please enter a name, grade, team, and bib number for the runner');
      return;
    }

    Logger.d(
        'Creating new runner with bib: "${bibController.text}", name: "${nameController.text}"');

    try {
      // Create runner with form data
      final formRunner = Runner(
        bibNumber: bibController.text, // Use bib from form
        name: nameController.text,
        grade: int.tryParse(gradeController.text),
      );

      // Find the team by name (this is a bit hacky, but necessary since teamController only has the name)
      final teams = await masterRace.teams;
      final selectedTeam = teams.firstWhere(
        (team) => team.name == teamController.text,
        orElse: () => raceRunner.team, // fallback to original team
      );
      Logger.d(
          'Selected team: ${selectedTeam.name} (id: ${selectedTeam.teamId}) for new runner');

      // Create new raceRunner with form data
      final formRaceRunner = RaceRunner(
        raceId: raceRunner.raceId,
        runner: formRunner,
        team: selectedTeam,
      );

      // Check if runner already exists by bib
      final existingRunner =
          await masterRace.db.getRunnerByBib(formRunner.bibNumber!);

      int runnerId;
      if (existingRunner == null) {
        // Create new runner and get the ID
        runnerId = await masterRace.db.createRunner(formRunner);
        masterRace.db.addRunnerToTeam(selectedTeam.teamId!, runnerId);
      } else {
        // Runner already exists, use existing ID
        runnerId = existingRunner.runnerId!;
      }

      // Update the raceRunner with the correct runner ID
      final updatedRaceRunner = RaceRunner(
        raceId: formRaceRunner.raceId,
        runner: formRunner.copyWith(runnerId: runnerId),
        team: selectedTeam,
      );

      // Add runner to the race
      await masterRace.addRaceParticipant(RaceParticipant(
          raceId: raceId, runnerId: runnerId, teamId: selectedTeam.teamId!));

      // Return the updated records immediately
      Logger.d(
          'Created new RaceRunner: ${updatedRaceRunner.runner.name} (bib: ${updatedRaceRunner.runner.bibNumber}, team: ${updatedRaceRunner.team.name})');
      onComplete(updatedRaceRunner);
    } catch (e) {
      Logger.e('Error creating new runner: $e');
      if (context.mounted) {
        DialogUtils.showErrorDialog(context,
            message: 'Failed to create runner: $e');
      }
    }
  }

  Future<void> assignExistingRaceRunner(RaceRunner raceRunner) async {
    if (raceRunners
        .any((r) => r.runner.bibNumber == raceRunner.runner.bibNumber)) {
      DialogUtils.showErrorDialog(context,
          message: 'This bib number is already assigned to another runner');
      return;
    }

    final confirmed = await DialogUtils.showConfirmationDialog(context,
        title: 'Assign Runner',
        content:
            'Are you sure this is the correct runner? \nName: ${raceRunner.runner.name} \nGrade: ${raceRunner.runner.grade ?? 'N/A'} \nTeam: ${raceRunner.team.name} \nBib Number: ${raceRunner.runner.bibNumber}');

    // Check if context is still mounted after the async operation
    if (!context.mounted || !confirmed) return;

    onComplete(raceRunner);
  }

  @override
  void dispose() {
    searchController.dispose();
    nameController.dispose();
    gradeController.dispose();
    teamController.dispose();
    bibController.dispose();
    masterRace.removeListener(() {
      notifyListeners();
    });
    _context = null;
    super.dispose();
  }
}
