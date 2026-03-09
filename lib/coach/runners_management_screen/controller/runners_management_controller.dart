import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xceleration/core/services/service_locator.dart';
import 'package:xceleration/core/services/sync_service.dart';
import 'package:xceleration/core/utils/i_database_helper.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/team_participant.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../core/components/runner_input_form.dart';
import '../../../core/utils/file_processing.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../shared/models/database/master_race.dart';
import '../../../shared/models/database/runner.dart';
import '../../../shared/models/database/team.dart';
import '../../../core/components/create_team_sheet.dart';
import '../widgets/existing_teams_browser_sheet.dart';
import '../widgets/edit_team_sheet.dart';
import '../../../shared/models/database/race_participant.dart';
import '../widgets/add_runners_to_team_sheet.dart';
import '../widgets/imported_runners_selection_sheet.dart';
import '../widgets/spreadsheet_load_sheet.dart';

class RunnersManagementController with ChangeNotifier {
  final VoidCallback? onBack;
  final VoidCallback? onContentChanged;
  final bool isViewMode;
  bool showHeader = true;

  // Use MasterRace for all data management
  final MasterRace masterRace;

  // Database Helper
  late final IDatabaseHelper db;

  // Store the listener function to properly remove it later
  late final VoidCallback _masterRaceListener;

  StreamSubscription? _syncSubscription;

  // UI state
  bool isLoading = true;
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
  }) {
    db = ServiceLocator.get<IDatabaseHelper>();
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

      _updateFilteredRaceRunners();
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

  void filterRaceRunners(String query) async {
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

  void _updateFilteredRaceRunners() async {
    filterRaceRunners(searchController.text);
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
          getRunnerByBib: db.getRunnerByBib,
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
          await db.getRunnerByBib(raceRunner.runner.bibNumber!);
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

    // Remove current runner's race mapping if it exists
    if (oldRunnerId != null) {
      final currentRp = await db.getRaceParticipant(
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
    await db.updateRunner(updatedExisting);

    // Update team mappings for the existing runner
    await _updateRunnerTeamMappings(existingRunner.runnerId!, targetTeamId);

    // If there was an old distinct runner, delete it globally so only one remains
    if (oldRunnerId != null && oldRunnerId != existingRunner.runnerId) {
      await db.deleteRunnerEverywhere(oldRunnerId);
    }

    // Force refresh and close
    await forceRefresh();
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _createNewRunner(RaceRunner raceRunner, int targetTeamId) async {
    // Create new runner
    final newRunnerId = await db.createRunner(raceRunner.runner);

    // Add to team roster
    await db.addRunnerToTeam(targetTeamId, newRunnerId);

    // Add to race
    await masterRace.addRaceParticipant(RaceParticipant(
      raceId: masterRace.raceId,
      runnerId: newRunnerId,
      teamId: targetTeamId,
    ));
  }

  Future<void> _updateExistingRunner(
      RaceRunner raceRunner, int targetTeamId) async {
    // Update runner details and team mappings
    await db.updateRunnerWithTeams(
      runner: raceRunner.runner,
      newTeamId: targetTeamId,
      raceIdForTeamUpdate: masterRace.raceId,
    );

    // Ensure no duplicates by bib remain after an update
    final currentId = raceRunner.runner.runnerId!;
    final bib = raceRunner.runner.bibNumber!;
    final allWithBib = await db.getRunnersByBibAll(bib);
    for (final r in allWithBib) {
      if (r.runnerId != null && r.runnerId != currentId) {
        await db.deleteRunnerEverywhere(r.runnerId!);
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
    await db.setRunnerTeam(runnerId, newTeamId);

    // Check if runner is already in this race
    final existingRp = await db.getRaceParticipant(
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
      await db.updateRaceParticipantTeam(
        raceId: masterRace.raceId,
        runnerId: runnerId,
        newTeamId: newTeamId,
      );
      await masterRace.updateRaceParticipant(RaceParticipant(
        raceId: masterRace.raceId,
        runnerId: runnerId,
        teamId: newTeamId,
      ));
    } else {}
  }

  // ============================================================================
  // TEAM OPERATIONS
  // ============================================================================

  Future<void> createTeam(Team team) async {
    if (team.name == null || team.name!.trim().isEmpty) return;

    try {
      // Check if team already exists
      final existingTeam = await masterRace.getTeamByName(team.name!);
      if (existingTeam != null) {
        // Team already exists, do nothing
        return;
      }

      // Persist team and capture newly assigned id
      final newTeamId = await db.createTeam(team);

      await masterRace.addTeamParticipant(TeamParticipant(
        raceId: masterRace.raceId,
        teamId: newTeamId,
        colorOverride: team.color?.toARGB32(),
      ));
      onContentChanged?.call();
      loadData();
    } catch (e) {
      Logger.e('Error creating team: $e');
      throw Exception('Failed to create team: $e');
    }
  }

  Future<void> showAddRunnerToTeam(BuildContext context, Team team) async {
    await showRaceRunnerSheet(context: context, team: team);
  }

  Future<void> showImportRunnersToTeam(BuildContext context, Team team) async {
    await loadSpreadsheet(context, team);
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
      await showAddRunnersToTeamSheet(context, persisted);
    }
  }

  Future<void> showAddRunnersToTeamSheet(
      BuildContext context, Team team) async {
    await sheet(
      context: context,
      title: 'Add Runners to ${team.abbreviation}',
      body: AddRunnersToTeamSheet(
        masterRace: masterRace,
        team: team,
        onComplete: (selectedRunnerIds) async {
          // Add selected existing runners in bulk to avoid repeated rebuilds
          final participants = selectedRunnerIds
              .map((runnerId) => RaceParticipant(
                    raceId: masterRace.raceId,
                    runnerId: runnerId,
                    teamId: team.teamId!,
                  ))
              .toList();
          if (participants.isNotEmpty) {
            await masterRace.addRaceParticipantsBulk(participants);
          }
          onContentChanged?.call();
          await loadData();
        },
        onRequestManualAdd: () async {
          await showAddRunnerToTeam(context, team);
          await loadData();
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
            await db.updateTeam(updatedTeam);
            // If color/name changed, ensure race team participation reflects color override when shown
            onContentChanged?.call();
            await loadData();
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
        final runners = await db.getTeamRunners(team.teamId!);
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
            await db.addRunnerToTeam(team.teamId!, runner.runnerId!);
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

      onContentChanged?.call();
      await loadData();
      return true;
    } catch (e) {
      Logger.e('Error deleting team: $e');
      return false;
    }
  }

  Future<void> loadSpreadsheet(BuildContext context, Team team) async {
    final bool useGoogleDrive = await showSpreadsheetLoadSheet(context);
    if (!context.mounted) return;

    try {
      final List<Map<String, dynamic>> importData = await processSpreadsheet(
        context,
        useGoogleDrive: useGoogleDrive,
      );

      if (importData.isEmpty) {
        if (context.mounted) {
          DialogUtils.showErrorDialog(context,
              message: 'No Valid Runners Loaded');
        }
        return;
      }

      // Let the user select which imported rows to add
      if (!context.mounted) return;
      final selectedRows = await sheet(
        context: context,
        title: 'Select Runners to Add',
        body: ImportedRunnersSelectionSheet(importedRunners: importData),
      ) as List<Map<String, dynamic>>?;

      // If user cancels or selects none, stop silently
      if (selectedRows == null || selectedRows.isEmpty) {
        return;
      }

      // Track conflicts where an existing runner (by bib) has different details
      final conflicts = <Map<String, Runner>>[];

      // Clear filtered search results cache to prevent stale data
      masterRace.invalidateCache();

      // First pass: add all non-conflicting runners immediately
      for (final data in selectedRows) {
        final String name = (data['name'] as String?)?.trim() ?? '';
        final int grade = (data['grade'] as int?) ?? 0;
        final String bib = (data['bib'] as String?)?.trim() ?? '';

        if (name.isEmpty || bib.isEmpty || grade <= 0) {
          Logger.d(
              'Skipping invalid spreadsheet row: name="$name", grade=$grade, bib="$bib"');
          continue;
        }

        final existingRunner = await db.getRunnerByBib(bib);
        if (existingRunner != null) {
          final bool sameDetails = (existingRunner.name == name) &&
              ((existingRunner.grade ?? 0) == grade);

          // Ensure global roster mapping so team->runners queries work
          await db.addRunnerToTeam(team.teamId!, existingRunner.runnerId!);

          // If already in this race, update team if needed; otherwise add to race
          final existingRaceParticipant =
              await db.getRaceParticipantByBib(masterRace.raceId, bib);
          if (existingRaceParticipant == null) {
            await masterRace.addRaceParticipant(RaceParticipant(
              raceId: masterRace.raceId,
              runnerId: existingRunner.runnerId!,
              teamId: team.teamId!,
            ));
          } else if (existingRaceParticipant.teamId != team.teamId) {
            await db.updateRaceParticipantTeam(
              raceId: masterRace.raceId,
              runnerId: existingRunner.runnerId!,
              newTeamId: team.teamId!,
            );
            await masterRace.updateRaceParticipant(RaceParticipant(
              raceId: masterRace.raceId,
              runnerId: existingRunner.runnerId!,
              teamId: team.teamId!,
            ));
          }

          if (!sameDetails) {
            // Keep the imported values we want to apply if user confirms overwrite
            final replacement =
                Runner(name: name, bibNumber: bib, grade: grade);
            conflicts
                .add({'existing': existingRunner, 'replacement': replacement});
          }
          continue;
        }

        // Create brand-new runner
        final newRunner = Runner(name: name, bibNumber: bib, grade: grade);
        final newRunnerId = await db.createRunner(newRunner);
        await db.addRunnerToTeam(team.teamId!, newRunnerId);
        await masterRace.addRaceParticipant(RaceParticipant(
          raceId: masterRace.raceId,
          runnerId: newRunnerId,
          teamId: team.teamId!,
        ));
      }

      // Resolve conflicts interactively, one-by-one
      if (conflicts.isNotEmpty) {
        if (!context.mounted) return;
        for (final entry in conflicts) {
          final existing = entry['existing']!;
          final replacement = entry['replacement']!;
          if (!context.mounted) return;

          final overwrite = await DialogUtils.showConfirmationDialog(
            context,
            title: 'Resolve Conflict (Bib ${existing.bibNumber})',
            content:
                'Existing: ${existing.name} (Grade ${existing.grade})\nSpreadsheet: ${replacement.name} (Grade ${replacement.grade})\n\nUse spreadsheet values?',
            confirmText: 'Overwrite',
            cancelText: 'Keep Existing',
          );

          if (overwrite) {
            // Update existing runner in place (keeps FKs intact)
            await db.updateRunner(Runner(
              runnerId: existing.runnerId!,
              name: replacement.name,
              bibNumber: replacement.bibNumber,
              grade: replacement.grade,
            ));

            // Ensure team roster and race participation are correct
            await db.addRunnerToTeam(team.teamId!, existing.runnerId!);
            final existingRp = await db.getRaceParticipant(
              RaceParticipant(
                  raceId: masterRace.raceId, runnerId: existing.runnerId!),
            );
            if (existingRp == null) {
              await masterRace.addRaceParticipant(RaceParticipant(
                raceId: masterRace.raceId,
                runnerId: existing.runnerId!,
                teamId: team.teamId!,
              ));
            } else if (existingRp.teamId != team.teamId) {
              await db.updateRaceParticipantTeam(
                raceId: masterRace.raceId,
                runnerId: existing.runnerId!,
                newTeamId: team.teamId!,
              );
              await masterRace.updateRaceParticipant(RaceParticipant(
                raceId: masterRace.raceId,
                runnerId: existing.runnerId!,
                teamId: team.teamId!,
              ));
            }
          } else {
            // Keep existing details but ensure proper mapping/team in this race
            await db.addRunnerToTeam(team.teamId!, existing.runnerId!);
            final rp = await db.getRaceParticipantByBib(
                masterRace.raceId, existing.bibNumber!);
            if (rp == null) {
              await masterRace.addRaceParticipant(RaceParticipant(
                raceId: masterRace.raceId,
                runnerId: existing.runnerId!,
                teamId: team.teamId!,
              ));
            } else if (rp.teamId != team.teamId) {
              await db.updateRaceParticipantTeam(
                raceId: masterRace.raceId,
                runnerId: existing.runnerId!,
                newTeamId: team.teamId!,
              );
              await masterRace.updateRaceParticipant(RaceParticipant(
                raceId: masterRace.raceId,
                runnerId: existing.runnerId!,
                teamId: team.teamId!,
              ));
            }
          }
        }
      }

      onContentChanged?.call();
    } catch (e) {
      Logger.e('Error handling spreadsheet load: $e');
      if (context.mounted) {
        DialogUtils.showMessageDialog(
          context,
          title: 'Error',
          message: 'Error importing runners: $e',
        );
      }
    }
  }

  // ============================================================================
  // UTILITY METHODS AND DIALOGS
  // ============================================================================

  /// Force refresh the UI by clearing MasterRace caches and notifying listeners
  /// This is more efficient than reloading all data
  Future<void> forceRefresh() async {
    try {
      // Clear MasterRace caches to force fresh data loading
      masterRace.invalidateCache();

      // Update filtered results
      _updateFilteredRaceRunners();

      // Notify UI
      onContentChanged?.call();
    } catch (e) {
      Logger.e('Error: $e');
    }
  }

  Future<bool> showSpreadsheetLoadSheet(BuildContext context) async {
    final result = await sheet(
      context: context,
      title: 'Import Runners',
      titleSize: 24,
      body: const SpreadsheetLoadSheet(),
    );
    return result['useGoogleDrive'] ?? false;
  }

  @override
  void dispose() {
    searchController.dispose();
    masterRace.removeListener(_masterRaceListener);
    _syncSubscription?.cancel();
    super.dispose();
  }
}
