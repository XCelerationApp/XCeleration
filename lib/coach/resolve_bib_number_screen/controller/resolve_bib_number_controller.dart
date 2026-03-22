import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/material.dart' show ChangeNotifier, TextEditingController;
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/database/race_participant.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import '../../../shared/models/database/i_master_race_resolver.dart';
import '../../../shared/models/database/master_race.dart';
import '../../../shared/models/database/team.dart';

class ResolveBibNumberController with ChangeNotifier {
  late final IMasterRaceResolver masterRace;
  List<RaceRunner> searchResults = [];
  final TextEditingController searchController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController gradeController = TextEditingController();
  final TextEditingController teamController = TextEditingController();
  final TextEditingController bibController = TextEditingController();
  bool showCreateNew = false;
  final List<RaceRunner> raceRunners;
  late final Set<String?> _recordedBibs;
  late final VoidCallback _masterRaceListener;
  final int raceId;
  final Function(RaceRunner) onComplete;
  final RaceRunner raceRunner;

  ResolveBibNumberController({
    required this.raceRunners,
    required this.raceId,
    required this.onComplete,
    required this.raceRunner,
    IMasterRaceResolver? masterRace,
  }) {
    this.masterRace = masterRace ?? MasterRace.getInstance(raceId);
    _recordedBibs = raceRunners.map((rr) => rr.runner.bibNumber).toSet();

    // Listen to changes from MasterRace — stored so the same reference can
    // be passed to removeListener in dispose(). Only re-notifies when the
    // search results relevant to this screen actually change.
    _masterRaceListener = _onMasterRaceChanged;
    this.masterRace.addListener(_masterRaceListener);
  }

  /// Get all teams (cached by MasterRace)
  Future<List<Team>> get teams => masterRace.teams;

  /// Updates [showCreateNew] and notifies consumers so the screen does not
  /// need a separate setState call.
  void setShowCreateNew(bool value) {
    showCreateNew = value;
    notifyListeners();
  }

  /// Fetches and filters runners without notifying listeners.
  Future<List<RaceRunner>> _fetchFilteredResults(String query) async {
    List<RaceRunner> candidates;
    if (query.isEmpty) {
      candidates = await masterRace.raceRunners;
    } else {
      await masterRace.searchRaceRunners(query);
      candidates = (await masterRace.filteredSearchResults)
          .values
          .expand((list) => list)
          .toList();
    }
    return candidates
        .where((rr) => !_recordedBibs.contains(rr.runner.bibNumber))
        .toList();
  }

  /// Called when MasterRace notifies. Only rebuilds consumers if the results
  /// relevant to this screen have actually changed, preventing rebuilds caused
  /// by unrelated MasterRace mutations.
  void _onMasterRaceChanged() {
    _refreshIfResultsChanged();
  }

  Future<void> _refreshIfResultsChanged() async {
    final fresh = await _fetchFilteredResults(searchController.text);
    if (_resultsChanged(searchResults, fresh)) {
      searchResults = fresh;
      notifyListeners();
    }
  }

  bool _resultsChanged(List<RaceRunner> a, List<RaceRunner> b) {
    if (a.length != b.length) return true;
    for (int i = 0; i < a.length; i++) {
      if (a[i].runner.bibNumber != b[i].runner.bibNumber) return true;
    }
    return false;
  }

  Future<void> searchRunners(String query) async {
    Logger.d('Searching runners...');
    Logger.d('Query: $query');
    Logger.d('Race ID: $raceId');
    Logger.d('Already recorded bibs: ${_recordedBibs.join(', ')}');

    searchResults = await _fetchFilteredResults(query);
    notifyListeners();
    Logger.d('Filtered search results');
  }

  Future<AppError?> createNewRunner() async {
    if (nameController.text.isEmpty ||
        gradeController.text.isEmpty ||
        teamController.text.isEmpty ||
        bibController.text.isEmpty) {
      return const AppError(
          userMessage:
              'Please enter a name, grade, team, and bib number for the runner');
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
          await masterRace.getRunnerByBib(formRunner.bibNumber!);

      int runnerId;
      if (existingRunner == null) {
        // Create new runner and get the ID
        runnerId = await masterRace.createRunner(formRunner);
        masterRace.addRunnerToTeam(selectedTeam.teamId!, runnerId);
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
      return null;
    } catch (e) {
      Logger.e('Error creating new runner: $e');
      return AppError(userMessage: 'Failed to create runner. Please try again.');
    }
  }

  /// Returns an [AppError] if the runner's bib is already assigned; otherwise
  /// calls [onComplete] and returns null. The caller is responsible for showing
  /// a confirmation dialog before invoking this method.
  AppError? assignExistingRaceRunner(RaceRunner raceRunner) {
    if (raceRunners
        .any((r) => r.runner.bibNumber == raceRunner.runner.bibNumber)) {
      return const AppError(
          userMessage: 'This bib number is already assigned to another runner');
    }

    Logger.d(
        'Assigning existing race runner: $raceRunner to raceRunner: ${raceRunner.toString()}');
    onComplete(raceRunner);
    return null;
  }

  @override
  void dispose() {
    searchController.dispose();
    nameController.dispose();
    gradeController.dispose();
    teamController.dispose();
    bibController.dispose();
    masterRace.removeListener(_masterRaceListener);
    super.dispose();
  }
}
