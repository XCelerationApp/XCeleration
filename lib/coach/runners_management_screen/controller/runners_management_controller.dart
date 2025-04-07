import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/dialog_utils.dart';
import '../../../core/components/runner_input_form.dart';
import '../../../core/components/button_components.dart';
import '../../../core/theme/app_colors.dart';
import '../../../utils/database_helper.dart';
import '../../../utils/file_processing.dart';
import '../../../utils/sheet_utils.dart';
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
  BuildContext? _context;

  RunnersManagementController({
    required this.raceId,
    this.showHeader = true,
    this.onBack,
    this.onContentChanged,
  });

  void setContext(BuildContext context) {
    _context = context;
  }

  BuildContext get context => _context!;

  Future<void> init() async {
    initControllers();
    await loadData();
  }

  Future<void> loadData() async {
    debugPrint('Loading data...');
    await Future.wait([
      loadRunners(),
      loadTeams(),
    ]);
    isLoading = false;
    notifyListeners();
    debugPrint('Data loaded');
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

  Future<void> loadRunners() async {
    debugPrint('Loading runners...');
    runners = await DatabaseHelper.instance.getRaceRunners(raceId);
    filteredRunners = runners;
    sortRunners();
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

  Future<void> handleRunnerAction(String action, RunnerRecord runner) async {
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
    await DatabaseHelper.instance.deleteRaceRunner(raceId, runner.bib);
    await loadRunners();
  }

  // Dialog and Action Methods
  Future<void> showRunnerSheet({
    required BuildContext context,
    RunnerRecord? runner,
  }) async {
    final title = runner == null ? 'Add Runner' : 'Edit Runner';

    // Initialize controllers
    initControllers();

    if (runner != null) {
      nameController?.text = runner.name;
      gradeController?.text = runner.grade.toString();
      schoolController?.text = runner.school;
      bibController?.text = runner.bib;
    }

    try {
      await sheet(
          context: context,
          body: RunnerInputForm(
            nameController: nameController,
            gradeController: gradeController,
            schoolController: schoolController,
            bibController: bibController,
            schoolOptions: teams.map((team) => team.name).toList()..sort(),
            raceId: raceId,
            initialRunner: runner,
            onSubmit: (RunnerRecord runner) async {
              await handleRunnerSubmission(runner);
            },
            submitButtonText: runner == null ? 'Create' : 'Save',
            useSheetLayout: true,
            showBibField: true,
          ),
          title: title);
    } finally {
      // Always dispose controllers when sheet is closed
      disposeControllers();
    }
  }

  Future<void> handleRunnerSubmission(RunnerRecord runner) async {
    try {
      dynamic existingRunner;
      existingRunner =
          await DatabaseHelper.instance.getRaceRunnerByBib(raceId, runner.bib);
      print('existingRunner: $existingRunner');

      if (existingRunner != null) {
        // If we're updating the same runner (same ID), just update
        if (existingRunner['runner_id'] == runner.runnerId) {
          await updateRunner(runner);
        } else {
          // If a different runner exists with this bib, ask for confirmation
          final shouldOverwrite = await DialogUtils.showConfirmationDialog(
            context,
            title: 'Overwrite Runner',
            content:
                'A runner with bib number ${runner.bib} already exists. Do you want to overwrite it?',
          );

          if (!shouldOverwrite) return;

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
    Navigator.of(context).pop();
  }

  Future<void> insertRunner(RunnerRecord runner) async {
    print('Inserting runner: ${runner.toMap()}');
    await DatabaseHelper.instance.insertRaceRunner(runner);
  }

  Future<void> updateRunner(RunnerRecord runner) async {
    await DatabaseHelper.instance.updateRaceRunner(runner);
  }

  Future<void> confirmDeleteAllRunners(BuildContext context) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Confirm Deletion',
      content: 'Are you sure you want to delete all runners?',
    );

    if (!confirmed) return;

    await DatabaseHelper.instance.deleteAllRaceRunners(raceId);

    await loadRunners();
  }

  Future<void> showSampleSpreadsheet() async {
    final file = await rootBundle
        .loadString('assets/sample_sheets/sample_spreadsheet.csv');
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

  Future<bool?> showSpreadsheetLoadSheet(BuildContext context) async {
    return await sheet(
      context: context,
      title: 'Import Runners',
      titleSize: 24,
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.file_upload_outlined,
                size: 40,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 24), // Adjusted spacing for balance

            // Description text
            Text(
              'Import your runners from a CSV or Excel spreadsheet to quickly set up your race.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24), // Adjusted spacing for balance

            // See Example button - with rounded corners and shadow
            SecondaryButton(
              text: 'See Example',
              icon: Icons.description_outlined,
              iconSize: 20,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              borderRadius: 30,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              onPressed: () async => await showSampleSpreadsheet(),
            ),
            const SizedBox(height: 24), // Adjusted spacing for balance

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel Button
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(
                          color: Colors.grey[600]!, // Adding subtle border
                          width: 1,
                        ),
                      ),
                      minimumSize:
                          const Size(double.infinity, 56), // Full width button
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Import Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      minimumSize:
                          const Size(double.infinity, 56), // Full width button
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined,
                            size: 20,
                            color: Colors.white), // Ensuring color consistency
                        const SizedBox(width: 8),
                        Text(
                            'Import Now',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            color: Colors.white, // Ensuring color consistency
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> handleSpreadsheetLoad() async {
    final confirmed = await showSpreadsheetLoadSheet(context);
    if (confirmed == null || !confirmed) return;
    final List<RunnerRecord> runnerData =
        await processSpreadsheet(raceId, false);
    
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
    
    if (runnersFromDifferentSchool.isNotEmpty) {
      final schools = runnersFromDifferentSchool.map((runner) => runner.school).toSet();
      final schoolsList = schools.toList();
      final schoolsString = schoolsList.join(', ');
      final runnersFromDifferentSchoolDialog = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Runners from Different Schools',
        content: '${runnersFromDifferentSchool.length} runners are from different schools: $schoolsString. They will not be imported. Do you want to continue?',
      );
      if (!runnersFromDifferentSchoolDialog) return;
    }

    for (final runner in runnersToAdd) {
      await DatabaseHelper.instance.insertRaceRunner(runner);
    }
    await loadRunners();

    if (overwriteRunners.isEmpty) return;
    final overwriteRunnersBibs =
        overwriteRunners.map((runner) => runner['bib_number']).toList();
    final overwriteExistingRunners = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Confirm Overwrite',
      content:
          'Are you sure you want to overwrite the following runners with bib numbers: ${overwriteRunnersBibs.join(', ')}?',
    );
    if (!overwriteExistingRunners) return;
    for (final runner in overwriteRunners) {
      await DatabaseHelper.instance
          .deleteRaceRunner(raceId, runner['bib_number']);
      await DatabaseHelper.instance.insertRaceRunner(runner);
    }
    await loadRunners();
  }

  @override
  void dispose() {
    searchController.dispose();
    disposeControllers();
    super.dispose();
  }
}
