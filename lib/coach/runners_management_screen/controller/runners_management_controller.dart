import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/repositories/i_race_repository.dart';
import 'package:xceleration/core/repositories/i_runner_repository.dart';
import 'package:xceleration/core/repositories/i_team_repository.dart';
import 'package:xceleration/core/services/service_locator.dart';
import 'package:xceleration/core/services/sync_service.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/team_participant.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../core/components/runner_input_form.dart';
import '../../../core/utils/file_processing.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../shared/models/database/i_master_race_resolver.dart';
import '../../../shared/models/database/runner.dart';
import '../../../shared/models/database/team.dart';
import '../../../core/components/create_team_sheet.dart';
import '../widgets/existing_teams_browser_sheet.dart';
import '../widgets/edit_team_sheet.dart';
import '../../../shared/models/database/race_participant.dart';
import '../widgets/add_runners_to_team_sheet.dart';
import '../widgets/add_runner_choice_sheet.dart';
import '../widgets/add_team_choice_sheet.dart';
import '../widgets/imported_runners_selection_sheet.dart';
import '../widgets/recent_spreadsheets_sheet.dart';
import '../widgets/spreadsheet_load_sheet.dart';
import '../services/roster_importer.dart';
import '../services/roster_update.dart';
import '../widgets/roster_update_preview.dart';

class RunnersManagementController with ChangeNotifier {
  final VoidCallback? onBack;
  final VoidCallback? onContentChanged;
  final bool isViewMode;
  bool showHeader = true;

  // Use IMasterRaceResolver for all data management
  final IMasterRaceResolver masterRace;

  // Repository interfaces
  late final IRunnerRepository _runners;
  late final ITeamRepository _teams;
  late final IRaceRepository _races;

  // Store the listener function to properly remove it later
  late final VoidCallback _masterRaceListener;

  StreamSubscription? _syncSubscription;

  // UI state
  bool isLoading = true;
  int totalRunnerCount = 0;
  String searchAttribute = 'All';
  final TextEditingController searchController = TextEditingController();

  // Store initial state to compare with final state
  List<RaceRunner> _initialRaceRunners = [];

  RunnersManagementController({
    required this.masterRace,
    this.showHeader = true,
    this.onBack,
    this.onContentChanged,
    this.isViewMode = false,
    Stream<SyncEvent>? syncStream,
    IRunnerRepository? runners,
    ITeamRepository? teams,
    IRaceRepository? races,
  }) {
    _runners = runners ?? ServiceLocator.get<IRunnerRepository>();
    _teams = teams ?? ServiceLocator.get<ITeamRepository>();
    _races = races ?? ServiceLocator.get<IRaceRepository>();
    // Create and store the listener function
    _masterRaceListener = () {
      // The listener's only job is to tell the UI to rebuild.
      // The UI's FutureBuilder will then get the new, updated `filteredSearchResults`
      // from MasterRace. This avoids causing a new search and creating a loop.
      notifyListeners();
    };

    // Listen to changes from MasterRace
    masterRace.addListener(_masterRaceListener);

    // Refresh when a sync pull writes runner, team, or participant data
    _syncSubscription = syncStream
        ?.where((event) => event.changedTables
            .any((t) => t == 'runners' || t == 'teams' || t == 'race_participants'))
        .listen((_) => forceRefresh());
  }

  Future<void> init() async {
    await loadData();
  }

  Future<void> loadData() async {
    isLoading = true;
    notifyListeners();

    try {
      // Load initial data through MasterRace (will be cached)
      final raceRunners = await masterRace.raceRunners;

      // Capture initial state on first load
      if (_initialRaceRunners.isEmpty) {
        _initialRaceRunners = List.from(raceRunners);
      }

      totalRunnerCount = raceRunners.length;
      await _updateFilteredRaceRunners();
      isLoading = false;
      notifyListeners();
      onContentChanged?.call();
    } catch (e) {
      Logger.e('Error loading data: $e');
      isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // DATA ACCESS (delegated to MasterRace)
  // ============================================================================

  // ============================================================================
  // SEARCH AND FILTERING
  // ============================================================================

  Future<Map<Team, List<RaceRunner>>> get filteredSearchResults =>
      masterRace.filteredSearchResults;

  void setSearchAttribute(String value) {
    searchAttribute = value;
    notifyListeners();
    filterRaceRunners(searchController.text.trim());
  }

  Future<void> filterRaceRunners(String query) async {
    final searchAttr = (() {
      switch (searchAttribute) {
        case 'All':
          return 'all';
        case 'Bib Number':
          return 'bib';
        case 'Name':
          return 'name';
        case 'Grade':
          return 'grade';
        case 'Team':
          return 'team';
        default:
          return 'all';
      }
    })();

    await masterRace.searchRaceRunners(query, searchAttr);
    notifyListeners();
  }

  Future<void> _updateFilteredRaceRunners() async {
    await filterRaceRunners(searchController.text);
  }
  // ============================================================================
  // RUNNER OPERATIONS
  // ============================================================================

  Future<void> handleRaceRunnerAction(
      BuildContext context, String action, RaceRunner raceRunner) async {
    switch (action) {
      case 'Edit':
        await showRaceRunnerSheet(context: context, raceRunner: raceRunner);
        break;
      case 'Delete':
        final confirmed = await DialogUtils.showConfirmationDialog(
          context,
          title: 'Confirm Deletion',
          content: 'Are you sure you want to delete this runner?',
        );
        if (confirmed) {
          await deleteRaceRunner(raceRunner);
        }
        break;
    }
  }

  Future<void> deleteRaceRunner(RaceRunner raceRunner) async {
    try {
      await masterRace.removeRaceRunner(raceRunner);
      onContentChanged?.call();
    } catch (e) {
      Logger.e('Error deleting runner: $e');
      throw Exception('Failed to delete runner: $e');
    }
  }

  Future<void> showRaceRunnerSheet({
    required BuildContext context,
    RaceRunner? raceRunner,
    Team? team,
  }) async {
    final bool isEditing = raceRunner != null;
    final title = isEditing ? 'Edit Runner' : 'Add Runner';
    final teamsList = await masterRace.teams;
    if (!context.mounted) return;

    try {
      await sheet(
        context: context,
        body: RunnerInputForm(
          raceId: masterRace.raceId,
          teamOptions: teamsList,
          initialRaceRunner: raceRunner,
          // For create, must pass runnerTeam; for edit, selection is allowed within options
          runnerTeam: isEditing ? null : team,
          getRunnerByBib: _runners.getRunnerByBib,
          onSubmit: (RaceRunner raceRunner) async {
            await handleRunnerSubmission(context, raceRunner);
          },
          submitButtonText: raceRunner == null ? 'Create' : 'Save',
          useSheetLayout: true,
          showBibField: true,
        ),
        title: title,
      );
    } catch (e) {
      Logger.e('Error showing runner sheet: $e');
    }
  }

  Future<void> handleRunnerSubmission(
      BuildContext context, RaceRunner raceRunner) async {
    try {
      final int targetTeamId = raceRunner.team.teamId!;
      final existingRunner =
          await _runners.getRunnerByBib(raceRunner.runner.bibNumber!);
      if (!context.mounted) {
        return;
      }

      // Handle bib number conflicts
      if (existingRunner != null &&
          existingRunner.runnerId != raceRunner.runner.runnerId) {
        await _handleBibConflict(
            context, raceRunner, existingRunner, targetTeamId);
        return;
      }

      // Handle new runner creation
      if (raceRunner.runner.runnerId == null) {
        await _createNewRunner(raceRunner, targetTeamId);
      } else {
        await _updateExistingRunner(raceRunner, targetTeamId);
      }

      // Force refresh the UI to show changes immediately
      await forceRefresh();

      // Close the sheet
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } on DataInUseException {
      rethrow; // carries a message for the user
    } catch (e) {
      Logger.e('Error handling runner submission: $e');
      throw Exception('Failed to save runner: $e');
    }
  }

  Future<void> _handleBibConflict(
    BuildContext context,
    RaceRunner raceRunner,
    Runner existingRunner,
    int targetTeamId,
  ) async {
    final int? oldRunnerId = raceRunner.runner.runnerId;

    // This merge deletes the edited runner at the end. Check before changing
    // anything: deleting a runner cascades to their saved race results.
    if (oldRunnerId != null &&
        oldRunnerId != existingRunner.runnerId &&
        await _runners.countRaceResults(oldRunnerId) > 0) {
      throw DataInUseException(
          'Bib ${raceRunner.runner.bibNumber} already belongs to '
          '${existingRunner.name ?? 'another runner'}, and this runner has '
          'saved race results, so the two cannot be merged. Use a different '
          'bib number.');
    }

    // Remove current runner's race mapping if it exists
    if (oldRunnerId != null) {
      final currentRp = await _races.getRaceParticipant(
        RaceParticipant(
          raceId: masterRace.raceId,
          runnerId: oldRunnerId,
        ),
      );
      if (currentRp != null) {
        await masterRace.removeRaceParticipant(currentRp);
      }
    }

    // Update the existing runner with new details (overwrite)
    final updatedExisting = Runner(
      runnerId: existingRunner.runnerId!,
      name: raceRunner.runner.name,
      bibNumber: raceRunner.runner.bibNumber,
      grade: raceRunner.runner.grade,
    );
    await _runners.updateRunner(updatedExisting);

    // Update team mappings for the existing runner
    await _updateRunnerTeamMappings(existingRunner.runnerId!, targetTeamId);

    // If there was an old distinct runner, delete it globally so only one remains
    if (oldRunnerId != null && oldRunnerId != existingRunner.runnerId) {
      await _runners.deleteRunnerEverywhere(oldRunnerId);
    }

    // Force refresh and close
    await forceRefresh();
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _createNewRunner(RaceRunner raceRunner, int targetTeamId) async {
    // Create new runner
    final newRunnerId = await _runners.createRunner(raceRunner.runner);

    // Add to team roster
    await _runners.addRunnerToTeam(targetTeamId, newRunnerId);

    // Add to race
    await masterRace.addRaceParticipant(RaceParticipant(
      raceId: masterRace.raceId,
      runnerId: newRunnerId,
      teamId: targetTeamId,
    ));
  }

  Future<void> _updateExistingRunner(
      RaceRunner raceRunner, int targetTeamId) async {
    // Other runners with this bib are deleted below; refuse before changing
    // anything if one of them has saved race results.
    final duplicates = [
      for (final r in await _runners.getRunnersByBibAll(raceRunner.runner.bibNumber!))
        if (r.runnerId != null && r.runnerId != raceRunner.runner.runnerId) r,
    ];
    for (final r in duplicates) {
      if (await _runners.countRaceResults(r.runnerId!) > 0) {
        throw DataInUseException(
            'Another runner (${r.name ?? 'unnamed'}) also has bib '
            '${r.bibNumber} and has saved race results. Use a different bib '
            'number.');
      }
    }

    // Update runner details and team mappings
    await _races.updateRunnerWithTeams(
      runner: raceRunner.runner,
      newTeamId: targetTeamId,
      raceIdForTeamUpdate: masterRace.raceId,
    );

    // Ensure no duplicates by bib remain after an update
    final currentId = raceRunner.runner.runnerId!;
    final bib = raceRunner.runner.bibNumber!;
    final allWithBib = await _runners.getRunnersByBibAll(bib);
    for (final r in allWithBib) {
      if (r.runnerId != null && r.runnerId != currentId) {
        await _runners.deleteRunnerEverywhere(r.runnerId!);
      }
    }

    // Update race participant record
    await masterRace.updateRaceParticipant(RaceParticipant(
      raceId: masterRace.raceId,
      runnerId: currentId,
      teamId: targetTeamId,
    ));
  }

  Future<void> _updateRunnerTeamMappings(int runnerId, int newTeamId) async {
    // Update global team roster
    await _runners.setRunnerTeam(runnerId, newTeamId);

    // Check if runner is already in this race
    final existingRp = await _races.getRaceParticipant(
      RaceParticipant(
        raceId: masterRace.raceId,
        runnerId: runnerId,
      ),
    );

    if (existingRp == null) {
      // Add to race
      await masterRace.addRaceParticipant(RaceParticipant(
        raceId: masterRace.raceId,
        runnerId: runnerId,
        teamId: newTeamId,
      ));
    } else if (existingRp.teamId != newTeamId) {
      // Update team in race
      await _races.updateRaceParticipantTeam(
        raceId: masterRace.raceId,
        runnerId: runnerId,
        newTeamId: newTeamId,
      );
      await masterRace.updateRaceParticipant(RaceParticipant(
        raceId: masterRace.raceId,
        runnerId: runnerId,
        teamId: newTeamId,
      ));
    }
  }

  // ============================================================================
  // TEAM OPERATIONS
  // ============================================================================

  /// Creates [team], returning why it could not be created, or null on success.
  ///
  /// A name already in use used to return quietly and the sheet closed as
  /// though the team had been made. Team names are unique across the whole
  /// app, not just this race, so this happens to a coach who has the name on
  /// another race.
  Future<AppError?> createTeam(Team team) async {
    if (team.name == null || team.name!.trim().isEmpty) {
      return const AppError(userMessage: 'Enter a team name.');
    }

    try {
      final existingTeam = await masterRace.getTeamByName(team.name!);
      if (existingTeam != null) {
        return AppError(
            userMessage: 'A team named "${team.name}" already exists.');
      }

      // Persist team and capture newly assigned id
      final newTeamId = await _teams.createTeam(team);

      await masterRace.addTeamParticipant(TeamParticipant(
        raceId: masterRace.raceId,
        teamId: newTeamId,
        colorOverride: team.color?.toARGB32(),
      ));
      await forceRefresh();
      return null;
    } catch (e) {
      Logger.e('Error creating team: $e');
      return AppError(
        userMessage: 'Could not create the team. Please try again.',
        originalException: e,
      );
    }
  }

  Future<void> showAddRunnerToTeam(BuildContext context, Team team) async {
    await showRaceRunnerSheet(context: context, team: team);
  }

  Future<void> showImportRunnersToTeam(BuildContext context, Team team) async {
    await loadSpreadsheet(context, team);
  }

  Future<void> showAddTeamChoiceSheet(BuildContext context) async {
    final otherTeams = await masterRace.getOtherTeams();
    if (!context.mounted) return;
    await sheet(
      context: context,
      title: 'Add Team',
      body: AddTeamChoiceSheet(
        showImportFromPreviousRace: otherTeams.isNotEmpty,
        onImportFromPreviousRace: () async {
          Navigator.of(context).pop();
          if (!context.mounted) return;
          await showExistingTeamsBrowser(context);
        },
        onImportFromSpreadsheet: () async {
          Navigator.of(context).pop();
          if (!context.mounted) return;
          await showImportTeamFromSpreadsheet(context);
        },
        onCreateTeam: () async {
          Navigator.of(context).pop();
          if (!context.mounted) return;
          await showCreateTeamSheet(context);
        },
      ),
    );
  }

  /// Imports whole teams from a spreadsheet. Each row goes to the team in
  /// its Team (or School) column, created if the coach has no such team. A
  /// sheet with no team column is for one team, which the coach names.
  Future<void> showImportTeamFromSpreadsheet(BuildContext context) async {
    final rows = await pickSpreadsheetRows(context);
    if (rows == null || !context.mounted) return;

    Team? intoTeam;
    if (rows.runners.any((r) => (r['team'] as String?)?.isNotEmpty != true)) {
      // Some rows name no team: ask which team they are on.
      await DialogUtils.showMessageDialog(
        context,
        title: 'Which Team?',
        message: rows.runners.every((r) => r['team'] == null)
            ? 'This spreadsheet has no Team column, so its runners go on one '
                'team. Create that team next. To import several teams at '
                'once, add a Team column.'
            : 'Some rows have no team. Create the team they go on next.',
        doneText: 'Next',
      );
      if (!context.mounted) return;
      intoTeam = await _createTeamForImport(context);
      if (intoTeam == null || !context.mounted) return;
    }
    await _importRows(context, rows, intoTeam: intoTeam);
  }

  /// Opens Create Team and returns the saved team, or null if cancelled.
  Future<Team?> _createTeamForImport(BuildContext context) async {
    final createdTeam = await sheet(
      context: context,
      title: 'Create New Team',
      body: CreateTeamSheet(masterRace: masterRace, createTeam: createTeam),
    );
    if (createdTeam is! Team) return null;
    return await _teams.getTeamByName(createdTeam.name ?? '');
  }

  Future<void> showCreateTeamSheet(BuildContext context) async {
    final createdTeam = await sheet(
      context: context,
      title: 'Create New Team',
      body: CreateTeamSheet(
        masterRace: masterRace,
        createTeam: createTeam,
      ),
    );

    if (createdTeam is Team) {
      // Resolve the persisted team (with teamId) before proceeding
      Team? persisted = await masterRace.getTeamByName(createdTeam.name ?? '');
      // Fallback: reload teams and try again if not immediately available
      persisted ??= (await masterRace.teams).firstWhere(
          (t) => t.name == createdTeam.name,
          orElse: () => createdTeam);
      if (!context.mounted) return;
      await showAddRunnerChoiceSheet(context, persisted);
    }
  }

  Future<void> showAddRunnerChoiceSheet(BuildContext context, Team team) async {
    await sheet(
      context: context,
      title: 'Add Runner',
      body: AddRunnerChoiceSheet(
        onAddManually: () async {
          Navigator.of(context).pop();
          if (!context.mounted) return;
          await showAddRunnersToTeamSheet(context, team);
        },
        onImportFromSpreadsheet: () async {
          Navigator.of(context).pop();
          if (!context.mounted) return;
          await showImportRunnersToTeam(context, team);
        },
      ),
    );
  }

  Future<void> showAddRunnersToTeamSheet(
      BuildContext context, Team team) async {
    await sheet(
      context: context,
      title: 'Add Runner to ${team.abbreviation ?? team.name ?? "Team"}',
      body: AddRunnersToTeamSheet(
        team: team,
        raceId: masterRace.raceId,
        getRunnerByBib: _runners.getRunnerByBib,
        onSubmit: (raceRunner) async {
          await handleRunnerSubmission(context, raceRunner);
        },
      ),
    );
  }

  Future<void> showEditTeamSheet(BuildContext context, Team team) async {
    await sheet(
      context: context,
      title: 'Edit Team (Global)',
      body: EditTeamSheet(
        team: team,
        onSave: (updatedTeam) async {
          try {
            await _teams.updateTeam(updatedTeam);
            // If color/name changed, ensure race team participation reflects color override when shown
            await forceRefresh();
          } catch (e) {
            Logger.e('Failed to update team: $e');
            if (context.mounted) {
              DialogUtils.showErrorDialog(context,
                  message: 'Failed to update team');
            }
          }
        },
      ),
    );
  }

  Future<void> showExistingTeamsBrowser(BuildContext context) async {
    try {
      final otherTeams = await masterRace.getOtherTeams();

      if (!context.mounted) return;

      if (otherTeams.isEmpty) {
        await DialogUtils.showMessageDialog(
          context,
          title: 'Can\'t Import Teams',
          message:
              'You have no teams from other races to import. Create a race to add runners.',
        );
        return;
      }

      // Build Team -> Runners map for the sheet
      final Map<Team, List<Runner>> available = {};
      for (final team in otherTeams) {
        final runners = await _runners.getTeamRunners(team.teamId!);
        available[team] = runners;
      }
      if (!context.mounted) return;

      final selectedTeams = await sheet(
        context: context,
        title: 'Import Teams',
        body: ExistingTeamsBrowserSheet(
          availableTeams: available,
          raceId: masterRace.raceId,
        ),
      ) as Map<Team, List<Runner>>?;

      if (selectedTeams != null && selectedTeams.isNotEmpty) {
        // Add selected teams and their runners to the race with minimal UI rebuilds
        for (final entry in selectedTeams.entries) {
          final team = entry.key;
          final runners = entry.value;

          await masterRace.addTeamParticipant(TeamParticipant(
            raceId: masterRace.raceId,
            teamId: team.teamId!,
            colorOverride: team.color?.toARGB32(),
          ));

          // Persist global roster mappings first
          for (final runner in runners) {
            if (runner.runnerId == null) continue;
            await _runners.addRunnerToTeam(team.teamId!, runner.runnerId!);
          }

          // Then add all race participants in a single bulk update
          final participants = runners
              .where((r) => r.runnerId != null)
              .map((r) => RaceParticipant(
                    raceId: masterRace.raceId,
                    runnerId: r.runnerId!,
                    teamId: team.teamId!,
                  ))
              .toList();

          if (participants.isNotEmpty) {
            await masterRace.addRaceParticipantsBulk(participants);
          }
        }

        if (context.mounted) {
          DialogUtils.showMessageDialog(
            context,
            title: 'Teams Added',
            message: 'Added ${selectedTeams.length} team(s) to race',
          );
        }
      }
    } catch (e) {
      Logger.e('Error showing existing teams browser: $e');
    }
  }

  // ============================================================================
  // BULK OPERATIONS
  // ============================================================================

  Future<void> confirmDeleteAllRunners(BuildContext context) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Confirm Deletion',
      content:
          'Are you sure you want to delete all runners? This will also remove all teams.',
    );

    if (!confirmed) return;

    try {
      final raceParticipantsList = await masterRace.raceParticipants;
      for (final raceParticipant in raceParticipantsList) {
        if (raceParticipant.runnerId != null) {
          await masterRace.removeRaceParticipant(raceParticipant);
        }
      }

      final teamsList = await masterRace.teams;
      for (final team in teamsList) {
        await masterRace.removeTeamFromRace(TeamParticipant(
          raceId: masterRace.raceId,
          teamId: team.teamId!,
        ));
      }

      onContentChanged?.call();
    } catch (e) {
      Logger.e('Error deleting all runners: $e');
    }
  }

  Future<bool> confirmAndDeleteTeam(BuildContext context, Team team) async {
    try {
      final confirmed = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Remove Team From This Race?',
        content: 'This does not delete the team or its runners globally.',
        confirmText: 'Remove',
        cancelText: 'Cancel',
      );

      if (!confirmed) return false;

      await masterRace.removeTeamFromRace(TeamParticipant(
        raceId: masterRace.raceId,
        teamId: team.teamId!,
      ));

      await forceRefresh();
      return true;
    } catch (e) {
      Logger.e('Error deleting team: $e');
      return false;
    }
  }

  Future<void> loadSpreadsheet(BuildContext context, Team team) async {
    final rows = await pickSpreadsheetRows(context);
    if (rows == null || !context.mounted) return;
    // Imported onto this team: a Team column in the sheet is ignored here,
    // since the coach chose the team by tapping its + Runner button.
    final onThisTeam = SpreadsheetRows([
      for (final row in rows.runners) {...row}..remove('team'),
    ], rows.skipped);
    await _importRows(context, onThisTeam, intoTeam: team);
  }

  /// Asks where the spreadsheet is, reads it, and returns its rows, or null
  /// when cancelled or when there was nothing to import (already said).
  Future<SpreadsheetRows?> pickSpreadsheetRows(BuildContext context) async {
    final action = await showSpreadsheetLoadSheet(context);
    if (action == null || !context.mounted) return null;

    try {
      final SpreadsheetRows importData;
      if (action == SpreadsheetImportAction.recent) {
        final file = await sheet(
          context: context,
          title: 'Previously Selected',
          body: const RecentSpreadsheetsSheet(),
        );
        if (file == null || !context.mounted) return null;
        importData = await processSpreadsheetFromFile(context, file);
      } else {
        importData = await processSpreadsheet(
          context,
          useGoogleDrive: action == SpreadsheetImportAction.googleDrive,
        );
      }

      if (importData.runners.isEmpty) {
        final skipped = importData.skipped;
        if (skipped.isNotEmpty && context.mounted) {
          DialogUtils.showMessageDialog(
            context,
            title: 'No Runners Found',
            message: 'None of the rows could be imported:\n\n'
                '${skipped.take(5).join('\n')}'
                '${skipped.length > 5 ? '\n…and ${skipped.length - 5} more' : ''}'
                '\n\nEach runner needs a name, a grade from 9 to 12, and a '
                'bib number.',
          );
        }
        return null;
      }
      return importData;
    } catch (e) {
      Logger.e('Error handling spreadsheet load: $e');
      if (context.mounted) {
        DialogUtils.showMessageDialog(
          context,
          title: 'Could Not Import',
          message: 'The spreadsheet could not be read. Check it is a CSV, '
              'Excel (.xlsx) or Google Sheets file and try again.',
        );
      }
      return null;
    }
  }

  /// Lets the coach choose which rows to add, adds them, then settles any
  /// runner saved before with a different name or grade.
  Future<void> _importRows(
    BuildContext context,
    SpreadsheetRows rows, {
    Team? intoTeam,
  }) async {
    final selectedRows = await sheet(
      context: context,
      title: 'Select Runners to Add',
      body: ImportedRunnersSelectionSheet(
        importedRunners: rows.runners,
        skippedRows: rows.skipped,
      ),
    ) as List<Map<String, dynamic>>?;
    if (selectedRows == null || selectedRows.isEmpty) return;

    final importer = RosterImporter(
      raceId: masterRace.raceId,
      runners: _runners,
      teams: _teams,
      races: _races,
    );
    final RosterImportResult result;
    try {
      result = await importer.importRows(selectedRows, intoTeam: intoTeam);
    } catch (e) {
      Logger.e('Error importing runners: $e');
      if (context.mounted) {
        DialogUtils.showErrorDialog(context,
            message: 'Could not add the runners. Please try again.');
      }
      await forceRefresh();
      return;
    }
    await forceRefresh();
    if (!context.mounted) return;
    await _settleConflicts(context, importer, result.conflicts);

    if (!context.mounted) return;
    DialogUtils.showSuccessDialog(context, message: _describe(result));
  }

  /// Asks, for each bib already saved with other details, whose details to
  /// keep.
  Future<void> _settleConflicts(
    BuildContext context,
    RosterImporter importer,
    List<RunnerDetailsConflict> conflicts,
  ) async {
    for (final conflict in conflicts) {
      if (!context.mounted) break;
      final existing = conflict.existing;
      final useSheet = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Bib ${existing.bibNumber} Is Already Saved',
        content: 'Saved: ${existing.name}, grade ${existing.grade}\n'
            'Spreadsheet: ${conflict.name}, grade ${conflict.grade}\n\n'
            'Use the spreadsheet\'s details? Either way, bib '
            '${existing.bibNumber} is in this race.',
        confirmText: 'Use Spreadsheet',
        cancelText: 'Keep Saved',
      );
      if (useSheet) await importer.useSpreadsheetDetails(conflict);
    }
    if (conflicts.isNotEmpty) await forceRefresh();
  }

  /// Brings [team] in line with a newer copy of its roster spreadsheet,
  /// after showing the coach what will change.
  Future<void> updateTeamFromSpreadsheet(
      BuildContext context, Team team) async {
    final rows = await pickSpreadsheetRows(context);
    if (rows == null || !context.mounted) return;

    final forTeam = rowsForTeam(rows.runners, team);
    if (forTeam.isEmpty) {
      await DialogUtils.showMessageDialog(
        context,
        title: 'No Runners for ${team.name}',
        message: 'The spreadsheet\'s Team column does not list '
            '${team.name}. Check the team name matches, or pick the sheet '
            'with just this team on it.',
      );
      return;
    }

    try {
      final plan = planRosterUpdate(
        current: await _runners.getTeamRunners(team.teamId!),
        rows: forTeam,
      );
      if (!context.mounted) return;
      if (plan.isEmpty) {
        DialogUtils.showSuccessDialog(context,
            message: '${team.name} already matches the spreadsheet.');
        return;
      }

      final confirmed = await sheet(
        context: context,
        title: 'Update ${team.name}',
        body: RosterUpdatePreview(plan: plan),
      );
      if (confirmed != true || !context.mounted) return;

      final updater = RosterUpdater(
        raceId: masterRace.raceId,
        runners: _runners,
        teams: _teams,
        races: _races,
      );
      final result = await updater.apply(plan, team);
      await forceRefresh();
      if (!context.mounted) return;

      final importer = RosterImporter(
        raceId: masterRace.raceId,
        runners: _runners,
        teams: _teams,
        races: _races,
      );
      await _settleConflicts(context, importer, result.imported.conflicts);
      if (!context.mounted) return;

      if (result.bibTaken.isNotEmpty) {
        await DialogUtils.showMessageDialog(
          context,
          title: 'Some Bibs Are Taken',
          message: 'These bibs already belong to other runners, so these '
              'runners kept their old ones:\n\n'
              '${result.bibTaken.map((c) => '${c.after.name}: bib ${c.after.bibNumber}').join('\n')}',
        );
        if (!context.mounted) return;
      }
      DialogUtils.showSuccessDialog(context,
          message: _describeUpdate(team, result));
    } catch (e) {
      Logger.e('Error updating team from spreadsheet: $e');
      await forceRefresh();
      if (context.mounted) {
        DialogUtils.showErrorDialog(context,
            message: 'Could not update ${team.name}. Please try again.');
      }
    }
  }

  static String _describeUpdate(Team team, RosterUpdateResult r) {
    String n(int count, String what) => '$count $what';
    final parts = [
      if (r.imported.total > 0) n(r.imported.total, 'added'),
      if (r.changed > 0) n(r.changed, 'changed'),
      if (r.removed > 0) n(r.removed, 'removed'),
    ];
    return parts.isEmpty
        ? '${team.name} is up to date.'
        : 'Updated ${team.name}: ${parts.join(', ')}.';
  }

  static String _describe(RosterImportResult r) {
    final parts = <String>[
      'Added ${r.total} runner${r.total == 1 ? '' : 's'}',
      if (r.teamsAdded.length > 1) 'on ${r.teamsAdded.length} teams',
      if (r.teamsAdded.length == 1) 'to ${r.teamsAdded.first}',
    ];
    var message = '${parts.join(' ')}.';
    if (r.teamsCreated.isNotEmpty) {
      message += ' New team${r.teamsCreated.length == 1 ? '' : 's'}: '
          '${r.teamsCreated.join(', ')}.';
    }
    if (r.unplaced > 0) {
      message += ' ${r.unplaced} had no team and were left out.';
    }
    return message;
  }

  // ============================================================================
  // UTILITY METHODS AND DIALOGS
  // ============================================================================

  /// Force refresh the UI by clearing MasterRace caches and notifying listeners
  /// This is more efficient than reloading all data (no loading flash).
  Future<void> forceRefresh() async {
    try {
      // Clear MasterRace caches to force fresh data loading
      masterRace.invalidateCache();

      // Keep totalRunnerCount accurate without a loading-state cycle
      final raceRunners = await masterRace.raceRunners;
      totalRunnerCount = raceRunners.length;

      // Update filtered results and notify UI
      await _updateFilteredRaceRunners();
      notifyListeners();

      onContentChanged?.call();
    } catch (e) {
      Logger.e('Error: $e');
    }
  }

  Future<SpreadsheetImportAction?> showSpreadsheetLoadSheet(
      BuildContext context) async {
    return await sheet(
      context: context,
      title: 'Import from a Spreadsheet',
      body: const SpreadsheetLoadSheet(),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    masterRace.removeListener(_masterRaceListener);
    _syncSubscription?.cancel();
    super.dispose();
  }
}
