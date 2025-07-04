import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../core/utils/database_helper.dart';
import '../../race_screen/widgets/runner_record.dart';

class ResolveBibNumberController with ChangeNotifier {
  final DatabaseHelper databaseHelper = DatabaseHelper.instance;
  List<RunnerRecord> searchResults = [];
  final TextEditingController searchController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController gradeController = TextEditingController();
  final TextEditingController schoolController = TextEditingController();
  bool showCreateNew = false;
  final List<RunnerRecord> records;
  final int raceId;
  final Function(RunnerRecord) onComplete;
  final RunnerRecord record;

  BuildContext? _context;

  ResolveBibNumberController({
    required this.records,
    required this.raceId,
    required this.onComplete,
    required this.record,
  });

  void setContext(BuildContext context) {
    _context = context;
  }

  BuildContext get context {
    assert(_context != null,
        'Context not set in ResolveBibNumberController. Call setContext() first.');
    return _context!;
  }

  Future<void> searchRunners(String query) async {
    Logger.d('Searching runners...');
    Logger.d('Query: $query');
    Logger.d('Race ID: $raceId');

    // Get already recorded runners for this race (runners that already have results)
    final recordedBibs = records.map((result) => result.bib).toSet();

    Logger.d('Already recorded bibs: ${recordedBibs.join(', ')}');

    List<RunnerRecord> results;
    if (query.isEmpty) {
      // Get all race runners
      results = await databaseHelper.getRaceRunners(raceId);
    } else {
      // Search race runners by query
      results = await databaseHelper.searchRaceRunners(raceId, query);
    }

    // Filter out runners that have already been recorded
    searchResults =
        results.where((runner) => !recordedBibs.contains(runner.bib)).toList();

    notifyListeners();
    Logger.d(
        'Filtered search results: ${searchResults.map((r) => r.bib).join(', ')}');
  }

  Future<void> createNewRunner() async {
    if (nameController.text.isEmpty ||
        gradeController.text.isEmpty ||
        schoolController.text.isEmpty) {
      DialogUtils.showErrorDialog(context,
          message: 'Please enter a name, grade, and school for the runner');
      return;
    }

    final runner = RunnerRecord(
      name: nameController.text,
      bib: record.bib,
      raceId: raceId,
      grade: int.parse(gradeController.text),
      school: schoolController.text,
    );

    await databaseHelper.insertRaceRunner(runner);
    record.error = null;

    // Update the current record with the new runner information
    record.name = runner.name;
    record.grade = runner.grade;
    record.school = runner.school;

    // Return the updated records immediately
    onComplete(record);
  }

  Future<void> assignExistingRunner(RunnerRecord runner) async {
    if (records.any((record) => record.bib == runner.bib && record != record)) {
      DialogUtils.showErrorDialog(context,
          message: 'This bib number is already assigned to another runner');
      return;
    }
    final confirmed = await DialogUtils.showConfirmationDialog(context,
        title: 'Assign Runner',
        content:
            'Are you sure this is the correct runner? \nName: ${runner.name} \nGrade: ${runner.grade} \nSchool: ${runner.school} \nBib Number: ${runner.bib}');

    // Check if context is still mounted after the async operation
    if (!context.mounted || !confirmed) return;

    // Update all fields from the selected runner
    record.bib = runner.bib;
    record.error = null;
    record.name = runner.name;
    record.grade = runner.grade;
    record.school = runner.school;
    record.runnerId = runner.runnerId;
    record.flags = runner.flags;
    record.raceId = runner.raceId;

    // Return the updated records immediately
    onComplete(record);
  }

  @override
  void dispose() {
    searchController.dispose();
    nameController.dispose();
    gradeController.dispose();
    schoolController.dispose();
    _context = null;
    super.dispose();
  }
}
