import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import '../../../core/components/dropup_button.dart';
import 'package:flutter/services.dart';
import 'package:xceleration/core/theme/typography.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../core/components/runner_input_form.dart';
import '../../../core/utils/database_helper.dart';
import '../../../core/utils/file_processing.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../race_screen/widgets/runner_record.dart';
import '../model/team.dart';

class RunnersManagementController with ChangeNotifier {
  List<RunnerRecord> runners = [];
  List<RunnerRecord> filteredRunners = [];
  final List<Team> teams = [];
  bool isLoading = true;
  bool showHeader = true;
  String searchAttribute = 'Bib Number';
  final TextEditingController searchController = TextEditingController();

  // Sheet controllers
  TextEditingController? nameController;
  TextEditingController? gradeController;
  TextEditingController? schoolController;
  TextEditingController? bibController;

  final int raceId;
  final VoidCallback? onBack;
  final VoidCallback? onContentChanged;
  final bool isViewMode;

  // Store initial state to compare with final state
  List<RunnerRecord> _initialRunners = [];

  RunnersManagementController({
    required this.raceId,
    this.showHeader = true,
    this.onBack,
    this.onContentChanged,
    this.isViewMode = false,
  });

  Future<void> init() async {
    initControllers();
    await loadData();
  }

  Future<void> loadData() async {
    Logger.d('Loading data...');
    await Future.wait([
      loadRunners(),
      loadTeams(),
    ]);
    isLoading = false;
    notifyListeners();
    Logger.d('Data loaded');
  }

  void initControllers() {
    disposeControllers(); // Clean up any existing controllers first
    nameController = TextEditingController();
    gradeController = TextEditingController();
    schoolController = TextEditingController();
    bibController = TextEditingController();
  }

  void disposeControllers() {
    nameController?.dispose();
    gradeController?.dispose();
    schoolController?.dispose();
    bibController?.dispose();
    nameController = null;
    gradeController = null;
    schoolController = null;
    bibController = null;
  }

  Future<void> loadTeams() async {
    final race = await DatabaseHelper.instance.getRaceById(raceId);
    teams.clear();
    for (var i = 0; i < race!.teams.length; i++) {
      teams.add(Team(name: race.teams[i], color: race.teamColors[i]));
    }
    notifyListeners();
  }

  /// Create a new team with a generated color
  Future<void> createTeam(String teamName) async {
    if (teamName.trim().isEmpty) return;

    final trimmedName = teamName.trim();

    // Check if team already exists
    if (teams.any((team) => team.name == trimmedName)) return;

    // Generate a new color for the team
    final newColor = _generateTeamColor(teams.length);

    // Add to local teams list
    final newTeam = Team(name: trimmedName, color: newColor);
    teams.add(newTeam);
    teams.sort((a, b) => a.name.compareTo(b.name));

    // Save to database
    await _saveTeamsToDatabase();

    notifyListeners();
    onContentChanged?.call();
    Logger.d('Created new team: $trimmedName');
  }

  /// Generate a color for a team based on the current number of teams
  Color _generateTeamColor(int index) {
    // Generate distinct colors using HSL color space
    final hue = (360 / 8 * index) % 360; // Spread across color wheel
    return HSLColor.fromAHSL(1.0, hue, 0.7, 0.5).toColor();
  }

  /// Save teams to database
  Future<void> _saveTeamsToDatabase() async {
    final teamNames = teams.map((team) => team.name).toList();
    final teamColors = teams.map((team) => team.color.toARGB32()).toList();

    await DatabaseHelper.instance.updateRaceField(raceId, 'teams', teamNames);
    await DatabaseHelper.instance
        .updateRaceField(raceId, 'teamColors', teamColors);
  }

  /// Delete a team from the local list and database
  Future<void> _deleteTeam(String teamName) async {
    if (teamName.trim().isEmpty) return;

    final trimmedName = teamName.trim();

    // Remove from local teams list
    teams.removeWhere((team) => team.name == trimmedName);

    // Save updated teams to database
    await _saveTeamsToDatabase();

    notifyListeners();
    onContentChanged?.call();
    Logger.d('Deleted team: $trimmedName');
  }

  /// Create multiple teams from a list of team names (used when loading from spreadsheet)
  Future<void> createTeamsFromList(List<String> teamNames) async {
    bool teamsAdded = false;

    for (final teamName in teamNames) {
      final trimmedName = teamName.trim();
      if (trimmedName.isEmpty) continue;

      // Check if team already exists
      if (teams.any((team) => team.name == trimmedName)) continue;

      // Generate a new color for the team
      final newColor = _generateTeamColor(teams.length);

      // Add to local teams list
      final newTeam = Team(name: trimmedName, color: newColor);
      teams.add(newTeam);
      teamsAdded = true;

      Logger.d('Created new team from spreadsheet: $trimmedName');
    }

    if (teamsAdded) {
      teams.sort((a, b) => a.name.compareTo(b.name));
      await _saveTeamsToDatabase();
      notifyListeners();
      onContentChanged?.call();
    }
  }

  /// Extract unique team names from a list of runners
  List<String> extractUniqueTeams(List<RunnerRecord> runners) {
    final teamNames = runners
        .map((runner) => runner.school.trim())
        .where((school) => school.isNotEmpty)
        .toSet()
        .toList();
    teamNames.sort();
    return teamNames;
  }

  Future<void> loadRunners() async {
    Logger.d('Loading runners...');
    runners = await DatabaseHelper.instance.getRaceRunners(raceId);
    filteredRunners = runners;
    sortRunners();

    // Capture initial state on first load
    if (_initialRunners.isEmpty) {
      _initialRunners = List.from(runners);
    }

    notifyListeners();
    onContentChanged?.call();
  }

  void sortRunners() {
    runners.sort((a, b) {
      final schoolCompare = a.school.compareTo(b.school);
      if (schoolCompare != 0) return schoolCompare;
      return a.name.compareTo(b.name);
    });
  }

  void filterRunners(String query) {
    if (query.isEmpty) {
      filteredRunners = List.from(runners);
    } else {
      filteredRunners = runners.where((runner) {
        final value = switch (searchAttribute) {
          'Bib Number' => runner.bib,
          'Name' => runner.name.toLowerCase(),
          'Grade' => runner.grade.toString(),
          'School' => runner.school.toLowerCase(),
          String() => '',
        };
        return value.contains(query.toLowerCase());
      }).toList();
    }
    notifyListeners();
  }

  Future<void> handleRunnerAction(
      BuildContext context, String action, RunnerRecord runner) async {
    switch (action) {
      case 'Edit':
        await showRunnerSheet(
          context: context,
          runner: runner,
        );
        break;
      case 'Delete':
        final confirmed = await DialogUtils.showConfirmationDialog(
          context,
          title: 'Confirm Deletion',
          content: 'Are you sure you want to delete this runner?',
        );
        if (confirmed) {
          await deleteRunner(runner);
          await loadRunners();
        }
        break;
    }
  }

  Future<void> deleteRunner(RunnerRecord runner) async {
    // Store the team name before deletion
    final deletedRunnerTeam = runner.school;

    // Delete the runner from database
    await DatabaseHelper.instance.deleteRaceRunner(raceId, runner.bib);

    // Reload runners to get updated list
    await loadRunners();

    // Check if this was the last runner from their team
    final remainingRunnersFromTeam =
        runners.where((r) => r.school == deletedRunnerTeam).toList();

    if (remainingRunnersFromTeam.isEmpty) {
      // Delete the team since no runners remain
      await _deleteTeam(deletedRunnerTeam);
      Logger.d('Deleted team "$deletedRunnerTeam" as no runners remain');
    }
  }

  // Dialog and Action Methods
  Future<void> showRunnerSheet({
    required BuildContext context,
    required RunnerRecord? runner,
  }) async {
    final title = runner == null ? 'Add Runner' : 'Edit Runner';

    try {
      await sheet(
          context: context,
          body: RunnerInputForm(
            initialName: runner?.name,
            initialGrade: runner?.grade.toString(),
            initialSchool: runner?.school,
            initialBib: runner?.bib,
            schoolOptions: teams.map((team) => team.name).toList()..sort(),
            raceId: raceId,
            initialRunner: runner,
            onSubmit: (RunnerRecord runner) async {
              // Make a copy of the runner data to avoid any issues
              final RunnerRecord runnerCopy = RunnerRecord(
                bib: runner.bib,
                name: runner.name,
                grade: runner.grade,
                school: runner.school,
                raceId: runner.raceId,
                runnerId: runner.runnerId,
                flags: runner.flags,
              );

              // Use post-frame callback to ensure form is fully done
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await handleRunnerSubmission(context, runnerCopy);
              });
            },
            onTeamCreated: (String teamName) async {
              // Handle new team creation
              await createTeam(teamName);
            },
            submitButtonText: runner == null ? 'Create' : 'Save',
            useSheetLayout: true,
            showBibField: true,
          ),
          title: title);
    } finally {
      // No need to dispose controllers as the form manages them internally now
    }
  }

  Future<void> handleRunnerSubmission(
      BuildContext context, RunnerRecord runner) async {
    try {
      RunnerRecord? existingRunner;
      existingRunner =
          await DatabaseHelper.instance.getRaceRunnerByBib(raceId, runner.bib);
      Logger.d('existingRunner: ${existingRunner?.toMap()}');

      if (existingRunner != null) {
        // If we're updating the same runner (same ID), just update
        if (existingRunner.runnerId == runner.runnerId) {
          Logger.d('Updating runner: ${runner.toMap()}');
          await updateRunner(runner);
        } else {
          // If a different runner exists with this bib, ask for confirmation
          // Check if context is still mounted before showing dialog
          if (!context.mounted) return;

          final shouldOverwrite = await DialogUtils.showConfirmationDialog(
            context,
            title: 'Overwrite Runner',
            content:
                'A runner with bib number ${runner.bib} already exists. Do you want to overwrite it?',
          );

          if (!shouldOverwrite) return;

          // Check if context is still mounted after confirmation dialog
          if (!context.mounted) return;

          await DatabaseHelper.instance.deleteRaceRunner(raceId, runner.bib);
          await insertRunner(runner);
        }
      } else {
        await insertRunner(runner);
      }

      await loadRunners();
      if (onContentChanged != null) {
        onContentChanged!();
      }
    } catch (e) {
      throw Exception('Failed to save runner: $e');
    }

    // Check if context is still mounted after async operations
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> insertRunner(RunnerRecord runner) async {
    Logger.d('Inserting runner: ${runner.toMap()}');
    await DatabaseHelper.instance.insertRaceRunner(runner);
  }

  Future<void> updateRunner(RunnerRecord runner) async {
    await DatabaseHelper.instance.updateRaceRunner(runner);
  }

  /// Reset flow state to sharing runners if actual changes were made
  Future<void> _resetFlowStateOnExit() async {
    // Compare current runners with initial state
    if (!_hasActualChanges()) return;

    final race = await DatabaseHelper.instance.getRaceById(raceId);
    if (race == null) return;

    // Check if flow state should be reset to sharing runners
    final shouldReset = _shouldResetToSharingRunners(race.flowState);
    if (shouldReset) {
      Logger.d(
          'Resetting flow state to sharing runners due to runner modifications');
      await DatabaseHelper.instance.updateRaceFlowState(raceId, 'pre-race');
    }
  }

  /// Check if there are actual changes between initial and current runners
  bool _hasActualChanges() {
    if (_initialRunners.length != runners.length) return true;

    // Convert to sets of runner identifiers for comparison
    final initialIds = _initialRunners
        .map((r) => '${r.bib}-${r.name}-${r.school}-${r.grade}')
        .toSet();
    final currentIds =
        runners.map((r) => '${r.bib}-${r.name}-${r.school}-${r.grade}').toSet();

    return !initialIds.containsAll(currentIds) ||
        !currentIds.containsAll(initialIds);
  }

  /// Check if flow state should be reset to sharing runners when runners are modified
  bool _shouldResetToSharingRunners(String? flowState) {
    if (flowState == null) return false;

    // Reset to sharing runners if the race is past the sharing runners step
    // This includes pre-race-completed and post-race states
    return flowState == 'pre-race-completed' || flowState == 'post-race';
  }

  Future<void> confirmDeleteAllRunners(BuildContext context) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Confirm Deletion',
      content:
          'Are you sure you want to delete all runners? This will also remove all teams.',
    );

    if (!confirmed) return;

    await DatabaseHelper.instance.deleteAllRaceRunners(raceId);

    // Clear all teams since no runners remain
    teams.clear();
    await _saveTeamsToDatabase();

    await loadRunners();
    Logger.d('Deleted all runners and cleared all teams');
  }

  Future<void> showSampleSpreadsheet(BuildContext context) async {
    final file = await rootBundle
        .loadString('assets/sample_sheets/sample_spreadsheet.csv');

    // Check if context is still mounted after async operation
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
      body: SingleChildScrollView(
        child: table,
      ),
    );
    return;
  }

  Future<Map<String, dynamic>?> showSpreadsheetLoadSheet(
      BuildContext context) async {
    return await sheet(
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
                // Title
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
                // Description
                const Text(
                  'Import your runners from a CSV or Excel spreadsheet. The file should have Name, Grade, School, and Bib Number columns in that order.',
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // View Sample Button
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

                // Import Button with Dropup Menu
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
                            // Icon(Icons.cloud, color: Color(0xFFE2572B), size: 20),
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
                            // Icon(Icons.folder_open, color: Color(0xFFE2572B), size: 20),
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
                        Text(
                          'Import Spreadsheet',
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                // const SizedBox(height: 12),

                // SizedBox(
                //   width: double.infinity,
                //   child: OutlinedButton(
                //     onPressed: () => Navigator.of(context).pop(),
                //     style: OutlinedButton.styleFrom(
                //       foregroundColor: Colors.grey[700],
                //       side: BorderSide(color: Colors.grey[400]!),
                //       padding: const EdgeInsets.symmetric(vertical: 12),
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(8),
                //       ),
                //     ),
                //     child: const Text(
                //       'Cancel',
                //       style: AppTypography.bodyMedium,
                //     ),
                //   ),
                // ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> handleSpreadsheetLoad(BuildContext context) async {
    final result = await showSpreadsheetLoadSheet(context);
    if (result == null) return;

    // Check if context is still mounted after sheet is closed
    if (!context.mounted) return;

    final bool useGoogleDrive = result['useGoogleDrive'] ?? false;

    final List<RunnerRecord> runnerData = await processSpreadsheet(
        raceId, false, context,
        useGoogleDrive: useGoogleDrive);

    if (runnerData.isEmpty) return;

    // Extract unique teams from the spreadsheet data
    final uniqueTeams = extractUniqueTeams(runnerData);
    final existingTeamNames = teams.map((team) => team.name).toList();
    final newTeams = uniqueTeams
        .where((teamName) => !existingTeamNames.contains(teamName))
        .toList();

    // Create new teams if any are found
    if (newTeams.isNotEmpty && context.mounted) {
      final shouldCreateTeams = await DialogUtils.showConfirmationDialog(
        context,
        title: 'New Teams Found',
        content:
            'Found ${newTeams.length} new team(s): ${newTeams.join(', ')}.\n\nDo you want to create these teams?',
        confirmText: 'Create Teams',
        cancelText: 'Cancel',
      );

      if (shouldCreateTeams) {
        await createTeamsFromList(newTeams);
        Logger.d('Created ${newTeams.length} new teams from spreadsheet');
      } else {
        // Filter out runners from teams that weren't created
        runnerData.removeWhere((runner) => newTeams.contains(runner.school));
        if (runnerData.isEmpty) {
          Logger.d('No runners to import after filtering out new teams');
          return;
        }
      }
    }

    final schools = (await DatabaseHelper.instance.getRaceById(raceId))?.teams;

    final overwriteRunners = [];
    final runnersFromDifferentSchool = [];
    final runnersToAdd = [];
    for (final runner in runnerData) {
      dynamic existingRunner;
      existingRunner =
          await DatabaseHelper.instance.getRaceRunnerByBib(raceId, runner.bib);
      if (existingRunner != null &&
          runner.bib == existingRunner.bib &&
          runner.name == existingRunner.name &&
          runner.school == existingRunner.school &&
          runner.grade == existingRunner.grade) {
        continue;
      }

      if (schools != null && !schools.contains(runner.school)) {
        runnersFromDifferentSchool.add(runner);
        continue;
      }
      if (existingRunner != null) {
        overwriteRunners.add(runner);
      } else {
        runnersToAdd.add(runner);
      }
    }

    if (runnersFromDifferentSchool.isNotEmpty && context.mounted) {
      final schools =
          runnersFromDifferentSchool.map((runner) => runner.school).toSet();
      final schoolsList = schools.toList();
      final schoolsString = schoolsList.join(', ');

      final shouldContinue = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Runners from Different Schools',
        content:
            '${runnersFromDifferentSchool.length} runners are from different schools: $schoolsString. They will not be imported. Do you want to continue?',
      );

      if (!shouldContinue) return;
    }

    for (final runner in runnersToAdd) {
      await DatabaseHelper.instance.insertRaceRunner(runner);
    }
    await loadRunners();

    if (overwriteRunners.isEmpty) return;
    final overwriteRunnersBibs =
        overwriteRunners.map((runner) => runner.bib).toList();

    if (context.mounted) {
      final shouldOverwriteRunners = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Confirm Overwrite',
        content:
            'Are you sure you want to overwrite the following runners with bib numbers: ${overwriteRunnersBibs.join(', ')}?',
      );
      if (!shouldOverwriteRunners) return;
    } else {
      Logger.d('Context not mounted, overwriting runners');
    }
    for (final runner in overwriteRunners) {
      await DatabaseHelper.instance.deleteRaceRunner(raceId, runner.bib);
      await DatabaseHelper.instance.insertRaceRunner(runner);
    }
    await loadRunners();
  }

  @override
  void dispose() {
    // Reset flow state if changes were made during this session
    _resetFlowStateOnExit();
    searchController.dispose();
    disposeControllers();
    super.dispose();
  }
}
