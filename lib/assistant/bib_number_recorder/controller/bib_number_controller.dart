import 'package:flutter/material.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';
import 'package:xcelerate/core/services/device_connection_service.dart';
import '../model/bib_records_provider.dart';
import '../../../../core/components/dialog_utils.dart';
import 'package:provider/provider.dart';

class BibNumberController {
  final BuildContext context;
  final List<RunnerRecord> runners;
  final ScrollController scrollController;
  DevicesManager devices;

  BibNumberController({
    required this.context,
    required this.runners,
    required this.scrollController,
    required this.devices,
  });

  // Runner management methods
  RunnerRecord? getRunnerByBib(String bibNumber) {
    try {
      final runner = runners.firstWhere(
        (runner) => runner.bib == bibNumber,
        orElse: () =>
            RunnerRecord(bib: '', name: '', raceId: -1, grade: -1, school: ''),
      );
      print('Runner found: ${runner.toMap()}');
      return (runner.raceId != -1) ? runner : null;
    } catch (e) {
      return null;
    }
  }

  List<RunnerRecord> decodeRunners(String encodedRunners, int raceId) {
    List<RunnerRecord> decodedRunners = [];
    for (var runner in encodedRunners.split(' ')) {
      if (runner.isNotEmpty) {
        List<String> runnerValues = runner.split(',');
        if (runnerValues.length == 4) {
          decodedRunners.add(RunnerRecord(
            raceId: raceId,
            bib: runnerValues[0],
            name: runnerValues[1],
            grade: int.parse(runnerValues[3]),
            school: runnerValues[2],
          ));
          //   'bib_number': runnerValues[0],
          //   'name': runnerValues[1],
          //   'school': runnerValues[2],
          //   'grade': runnerValues[3],
          // });
        }
      }
    }
    return decodedRunners;
  }

  // Bib number validation and handling
  Future<void> validateBibNumber(
      int index, String bibNumber, List<double>? confidences) async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final record = provider.bibRecords[index];

    // Reset all flags by creating a new RunnerRecordFlags object
    record.flags = const RunnerRecordFlags(
      lowConfidenceScore: false,
      notInDatabase: false,
      duplicateBibNumber: false,
    );
    record.name = '';
    record.school = '';

    // If bibNumber is empty, clear all flags and return
    if (bibNumber.isEmpty) {
      return;
    }

    bool lowConfidence = false;
    bool notInDb = false;
    bool duplicateBib = false;

    // Check confidence scores
    if (confidences?.any((score) => score < 0.9) ?? false) {
      lowConfidence = true;
    }

    // Check database
    final runner = getRunnerByBib(bibNumber);
    if (runner == null) {
      notInDb = true;
    } else {
      record.name = runner.name;
      record.school = runner.school;
    }

    // Check duplicates
    final duplicateIndexes = provider.bibRecords
        .asMap()
        .entries
        .where((e) => e.value.bib == bibNumber && e.value.bib.isNotEmpty)
        .map((e) => e.key)
        .toList();

    if (duplicateIndexes.length > 1) {
      // Mark as duplicate if this is not the first occurrence
      duplicateBib = duplicateIndexes.indexOf(index) > 0;
    }

    // Set all flags at once with a new object
    record.flags = RunnerRecordFlags(
      lowConfidenceScore: lowConfidence,
      notInDatabase: notInDb,
      duplicateBibNumber: duplicateBib,
    );
  }

  void onBibRecordRemoved(int index) {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    provider.removeBibRecord(index);

    // Revalidate all remaining bib numbers to update duplicate flags
    for (var i = 0; i < provider.bibRecords.length; i++) {
      validateBibNumber(i, provider.bibRecords[i].bib, null);
    }
  }

  Future<void> handleBibNumber(
    String bibNumber, {
    List<double>? confidences,
    int? index,
  }) async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);

    if (index != null) {
      await validateBibNumber(index, bibNumber, confidences);
      provider.updateBibRecord(index, bibNumber);
    } else {
      provider.addBibRecord(RunnerRecord(
        bib: bibNumber,
        name: '',
        raceId: -1,
        grade: -1,
        school: '',
        flags: const RunnerRecordFlags(
          notInDatabase: false,
          duplicateBibNumber: false,
          lowConfidenceScore: false,
        ),
      ));
      // Scroll to bottom when adding new bib
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
    }

    // Validate all bib numbers to update duplicate states
    for (var i = 0; i < provider.bibRecords.length; i++) {
      await validateBibNumber(
          i, provider.bibRecords[i].bib, i == index ? confidences : null);
    }

    if (runners.isNotEmpty) {
      Provider.of<BibRecordsProvider>(context, listen: false)
          .focusNodes[index ?? provider.bibRecords.length - 1]
          .requestFocus();
    }
  }

  void scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Sharing and data validation methods
  String getEncodedBibData() {
    final bibRecordsProvider =
        Provider.of<BibRecordsProvider>(context, listen: false);
    return bibRecordsProvider.bibRecords
        .map((record) => record.bib)
        .toList()
        .join(' ');
  }

  void restoreFocusability() {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    for (var node in provider.focusNodes) {
      node.canRequestFocus = true;
    }
  }

  Future<bool> cleanEmptyRecords() async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final emptyRecords =
        provider.bibRecords.where((bib) => bib.bib.isEmpty).length;

    if (emptyRecords > 0) {
      final confirmed = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Clean Empty Records',
        content:
            'There are $emptyRecords empty bib numbers that will be deleted. Continue?',
      );

      if (confirmed) {
        provider.bibRecords.removeWhere((bib) => bib.bib.isEmpty);
      }
      return confirmed;
    }
    return true;
  }

  Future<bool> checkDuplicateRecords() async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final duplicateRecords =
        provider.bibRecords.where((bib) => bib.flags.duplicateBibNumber).length;

    if (duplicateRecords > 0) {
      final confirmed = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Duplicate Bib Numbers',
        content:
            'There are $duplicateRecords duplicate bib numbers. Do you want to continue?',
      );
      return confirmed;
    }
    return true;
  }

  Future<bool> checkUnknownRecords() async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final unknownRecords =
        provider.bibRecords.where((bib) => bib.flags.notInDatabase).length;

    if (unknownRecords > 0) {
      final confirmed = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Unknown Bib Numbers',
        content:
            'There are $unknownRecords bib numbers that are not in the database. Do you want to continue?',
      );
      return confirmed;
    }
    return true;
  }
}
