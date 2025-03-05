import 'package:flutter/material.dart';
import 'dart:convert';
import '../model/bib_number_model.dart';
import '../model/bib_data.dart';
import '../../../../../core/components/dialog_utils.dart';
import '../../../../../shared/role_functions.dart';
import '../../../../../utils/enums.dart';
import 'package:provider/provider.dart';

class BibNumberController {
  final BuildContext context;
  final List<dynamic> runners;
  final ScrollController scrollController;
  final Map<DeviceName, Map<String, dynamic>> otherDevices;
  
  BibNumberController({
    required this.context,
    required this.runners,
    required this.scrollController,
    required this.otherDevices,
  });

  // Runner management methods
  dynamic getRunnerByBib(String bibNumber) {
    try {
      return runners.firstWhere(
        (runner) => runner['bib_number'] == bibNumber,
        orElse: () => null,
      );
    } catch (e) {
      return null;
    }
  }

  List<Map<String, dynamic>> decodeRunners(String encodedRunners) {
    List<Map<String, dynamic>> decodedRunners = [];
    for (var runner in encodedRunners.split(' ')) {
      if (runner.isNotEmpty) {
        List<String> runnerValues = runner.split(',');
        if (runnerValues.length == 4) {
          decodedRunners.add({
            'bib_number': runnerValues[0],
            'name': runnerValues[1],
            'school': runnerValues[2],
            'grade': runnerValues[3],
          });
        }
      }
    }
    return decodedRunners;
  }

  // Bib number validation and handling
  Future<void> validateBibNumber(int index, String bibNumber, List<double>? confidences) async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final record = provider.bibRecords[index];

    // Reset all flags first
    record.flags['low_confidence_score'] = false;
    record.flags['not_in_database'] = false;
    record.flags['duplicate_bib_number'] = false;
    record.name = '';
    record.school = '';

    // If bibNumber is empty, clear all flags and return
    if (bibNumber.isEmpty) {
      return;
    }

    // Check confidence scores
    if (confidences?.any((score) => score < 0.9) ?? false) {
      record.flags['low_confidence_score'] = true;
    }

    // Check database
    final runner = getRunnerByBib(bibNumber);
    if (runner == null) {
      record.flags['not_in_database'] = true;
    } else {
      record.name = runner['name'];
      record.school = runner['school'];
      record.flags['not_in_database'] = false;
    }

    // Check duplicates
    final duplicateIndexes = provider.bibRecords
      .asMap()
      .entries
      .where((e) => e.value.bibNumber == bibNumber && e.value.bibNumber.isNotEmpty)
      .map((e) => e.key)
      .toList();

    if (duplicateIndexes.length > 1) {
      // Mark as duplicate if this is not the first occurrence
      record.flags['duplicate_bib_number'] = duplicateIndexes.indexOf(index) > 0;
    }
  }

  void onBibRecordRemoved(int index) {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    provider.removeBibRecord(index);

    // Revalidate all remaining bib numbers to update duplicate flags
    for (var i = 0; i < provider.bibRecords.length; i++) {
      validateBibNumber(i, provider.bibRecords[i].bibNumber, null);
    }
  }

  Future<void> handleBibNumber(String bibNumber, {
    List<double>? confidences,
    int? index,
  }) async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    
    if (index != null) {
      await validateBibNumber(index, bibNumber, confidences);
      provider.updateBibRecord(index, bibNumber);
    } else {
      provider.addBibRecord(BibRecord(
        bibNumber: bibNumber,
        confidences: confidences ?? [],
      ));
      // Scroll to bottom when adding new bib
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
    }

    // Validate all bib numbers to update duplicate states
    for (var i = 0; i < provider.bibRecords.length; i++) {
      await validateBibNumber(i, provider.bibRecords[i].bibNumber, 
        i == index ? confidences : null);
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
    final bibRecordsProvider = Provider.of<BibRecordsProvider>(context, listen: false);
    return bibRecordsProvider.bibRecords.map((record) => record.bibNumber).toList().join(' ');
  }

  void restoreFocusability() {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    for (var node in provider.focusNodes) {
      node.canRequestFocus = true;
    }
  }

  Future<bool> cleanEmptyRecords() async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final emptyRecords = provider.bibRecords.where((bib) => bib.bibNumber.isEmpty).length;
    
    if (emptyRecords > 0) {
      final confirmed = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Clean Empty Records',
        content: 'There are $emptyRecords empty bib numbers that will be deleted. Continue?',
      );
      
      if (confirmed) {
        provider.bibRecords.removeWhere((bib) => bib.bibNumber.isEmpty);
      }
      return confirmed;
    }
    return true;
  }

  Future<bool> checkDuplicateRecords() async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final duplicateRecords = provider.bibRecords.where((bib) => bib.flags['duplicate_bib_number'] == true).length;
    
    if (duplicateRecords > 0) {
      final confirmed = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Duplicate Bib Numbers',
        content: 'There are $duplicateRecords duplicate bib numbers. Do you want to continue?',
      );
      return confirmed;
    }
    return true;
  }

  Future<bool> checkUnknownRecords() async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final unknownRecords = provider.bibRecords.where((bib) => bib.flags['not_in_database'] == true).length;
    
    if (unknownRecords > 0) {
      final confirmed = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Unknown Bib Numbers',
        content: 'There are $unknownRecords bib numbers that are not in the database. Do you want to continue?',
      );
      return confirmed;
    }
    return true;
  }
}
