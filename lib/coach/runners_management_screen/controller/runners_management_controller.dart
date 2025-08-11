import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/database_helper.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/team_participant.dart';
import '../../../core/components/dropup_button.dart';
import 'package:flutter/services.dart';
import 'package:xceleration/core/theme/typography.dart';
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

class RunnersManagementController with ChangeNotifier {
  final VoidCallback? onBack;
  final VoidCallback? onContentChanged;
  final bool isViewMode;
  bool showHeader = true;

  // Use MasterRace for all data management
  final MasterRace masterRace;

  // Database Helper
  final DatabaseHelper db = DatabaseHelper.instance;

  // Store the listener function to properly remove it later
  late final VoidCallback _masterRaceListener;

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
  }) {
    // Create and store the listener function
    _masterRaceListener = () {
      // The listener's only job is to tell the UI to rebuild.
      // The UI's FutureBuilder will then get the new, updated `filteredSearchResults`
      // from MasterRace. This avoids causing a new search and creating a loop.
      notifyListeners();
    };

    // Listen to changes from MasterRace
    masterRace.addListener(_masterRaceListener);
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
    final title = raceRunner == null ? 'Add Runner' : 'Edit Runner';
    final teamsList = await masterRace.teams;
    if (!context.mounted) return;

    try {
      await sheet(
        context: context,
        body: RunnerInputForm(
          masterRace: masterRace,
          teamOptions: teamsList,
          initialRaceRunner: raceRunner,
          requiredTeam: team ?? raceRunner?.team,
          onSubmit: (RaceRunner raceRunner) async {
            await handleRunnerSubmission(context, raceRunner);
          },
          onTeamCreated: (Team team) async {
            await createTeam(team);
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
      final existingRunner =
          await masterRace.db.getRunnerByBib(raceRunner.runner.bibNumber!);

      if (existingRunner != null &&
          existingRunner.runnerId != raceRunner.runner.runnerId) {
        // Different runner exists with this bib
        if (!context.mounted) return;

        final shouldOverwrite = await DialogUtils.showConfirmationDialog(
          context,
          title: 'Overwrite Runner',
          content:
              'A runner with bib number ${raceRunner.runner.bibNumber!} already exists. Do you want to overwrite it?',
        );

        if (!shouldOverwrite) return;

        // Remove existing runner first
        await masterRace.removeRaceRunner(raceRunner);
      }

      if (raceRunner.runner.runnerId == null) {
        // Create new runner
        final newRunnerId = await masterRace.db.createRunner(raceRunner.runner);
        // Ensure team roster mapping exists so team->runners queries work
        await masterRace.db
            .addRunnerToTeam(raceRunner.team.teamId!, newRunnerId);
        await masterRace.addRaceParticipant(RaceParticipant(
          raceId: masterRace.raceId,
          runnerId: newRunnerId,
          teamId: raceRunner.team.teamId,
        ));
      } else {
        // Update existing runner - need to implement update in MasterRace
        // For now, remove and re-add
        await masterRace.db.removeRunner(raceRunner.runner.runnerId!);
        final newRunnerId = await masterRace.db.createRunner(raceRunner.runner);
        await masterRace.db
            .addRunnerToTeam(raceRunner.team.teamId!, newRunnerId);
        await masterRace.addRaceParticipant(RaceParticipant(
          raceId: masterRace.raceId,
          runnerId: newRunnerId,
          teamId: raceRunner.team.teamId,
        ));
      }

      onContentChanged?.call();

      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      Logger.e('Error handling runner submission: $e');
      throw Exception('Failed to save runner: $e');
    }
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
          // Add selected existing runners
          for (final runnerId in selectedRunnerIds) {
            await masterRace.addRaceParticipant(RaceParticipant(
              raceId: masterRace.raceId,
              runnerId: runnerId,
              teamId: team.teamId!,
            ));
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
        // Add selected teams and their runners to the race
        for (final entry in selectedTeams.entries) {
          final team = entry.key;
          final runners = entry.value;

          await masterRace.addTeamParticipant(TeamParticipant(
            raceId: masterRace.raceId,
            teamId: team.teamId!,
            colorOverride: team.color?.toARGB32(),
          ));

          for (final runner in runners) {
            if (runner.runnerId == null) continue;
            // Persist roster mapping so team->runners queries work
            await db.addRunnerToTeam(team.teamId!, runner.runnerId!);
            await masterRace.addRaceParticipant(RaceParticipant(
              raceId: masterRace.raceId,
              runnerId: runner.runnerId!,
              teamId: team.teamId!,
            ));
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${selectedTeams.length} team(s) to race'),
              backgroundColor: Colors.green,
            ),
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
        title: 'Delete Team',
        content:
            'Remove ${team.name} from this race? This does not delete the team or its runners globally.',
        confirmText: 'Delete',
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

      if (importData.isEmpty) return;

      final existingRunners = <Runner>[];

      for (final runnerData in importData) {
        final runner = Runner(
          name: runnerData['name'] as String,
          bibNumber: runnerData['bibNumber'] as String,
          grade: int.parse(runnerData['grade'] as String),
        );
        if (runner.bibNumber == null) {
          Logger.e('Runner has no bib number: ${runner.name}');
          continue;
        }
        final existingRunner = await db.getRunnerByBib(runner.bibNumber!);
        if (existingRunner != null) {
          if (existingRunner.name == runner.name &&
              existingRunner.grade == runner.grade &&
              existingRunner.bibNumber == runner.bibNumber) {
            // Runner already exists with the same bib number, name, and grade, no need to create a new one
            continue;
          }
          existingRunners.add(existingRunner);
          continue;
        }
        final newRunnerId = await db.createRunner(runner);
        await masterRace.addRaceParticipant(RaceParticipant(
          raceId: masterRace.raceId,
          runnerId: newRunnerId,
          teamId: team.teamId!,
        ));
      }

      if (existingRunners.isNotEmpty) {
        if (!context.mounted) return;

        final shouldOverwrite = await DialogUtils.showConfirmationDialog(
          context,
          title: 'Overwrite Existing Runners',
          content:
              '${existingRunners.length} runner(s) already exist with the same bib numbers. Do you want to overwrite them?',
        );

        if (shouldOverwrite) {
          for (final existingRunner in existingRunners) {
            await db.removeRunner(existingRunner.runnerId!);
            final newRunnerId = await db.createRunner(existingRunner);
            await masterRace.addRaceParticipant(RaceParticipant(
              raceId: masterRace.raceId,
              runnerId: newRunnerId,
              teamId: team.teamId!,
            ));
          }
        }
      }

      onContentChanged?.call();
    } catch (e) {
      Logger.e('Error handling spreadsheet load: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing runners: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================================
  // UTILITY METHODS AND DIALOGS
  // ============================================================================

  Future<bool> showSpreadsheetLoadSheet(BuildContext context) async {
    final result = await sheet(
      context: context,
      title: 'Import Runners',
      titleSize: 24,
      body: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(
                    Icons.insert_drive_file_outlined,
                    color: Color(0xFFE2572B),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Import Runners from Spreadsheet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Import your runners from a CSV or Excel spreadsheet. The file should have Name, Grade, and Bib Number columns in that order.',
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => showSampleSpreadsheet(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE2572B),
                  ),
                  child: const Text(
                    'View Sample Spreadsheet',
                    style: AppTypography.bodyMedium,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: DropupButton<Map<String, dynamic>>(
                    onSelected: (result) {
                      if (result != null) {
                        Navigator.pop(context, result);
                      }
                    },
                    verticalOffset: 0,
                    elevation: 8,
                    menuShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    menuColor: Colors.white,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE2572B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [
                      PopupMenuItem<Map<String, dynamic>>(
                        value: {'useGoogleDrive': true},
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Select Google Sheet',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            Icon(Icons.arrow_forward_ios,
                                color: Color(0xFFE2572B), size: 20),
                          ],
                        ),
                      ),
                      PopupMenuItem<Map<String, dynamic>>(
                        value: {'useGoogleDrive': false},
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Select Local File',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            Icon(Icons.arrow_forward_ios,
                                color: Color(0xFFE2572B), size: 20),
                          ],
                        ),
                      ),
                    ],
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.file_upload, size: 20, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Import Spreadsheet',
                            style: AppTypography.bodyMedium),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    return result['useGoogleDrive'] ?? false;
  }

  Future<void> showSampleSpreadsheet(BuildContext context) async {
    final file = await rootBundle
        .loadString('assets/sample_sheets/sample_spreadsheet.csv');

    if (!context.mounted) return;

    final lines = file.split('\n');
    final table = Table(
      border: TableBorder.all(color: Colors.grey),
      children: lines.map((line) {
        final cells = line.split(',');
        return TableRow(
          children: cells.map((cell) {
            return TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(cell),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );

    await sheet(
      context: context,
      title: 'Sample Spreadsheet',
      body: SingleChildScrollView(child: table),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    masterRace.removeListener(_masterRaceListener);
    super.dispose();
  }
}
