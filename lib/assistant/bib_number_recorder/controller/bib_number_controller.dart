import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/bib_records_provider.dart';
import '../../../coach/race_screen/widgets/runner_record.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../core/services/device_connection_service.dart';

class BibNumberController {
  final BuildContext context;
  final List<RunnerRecord> runners;
  final ScrollController scrollController;
  final DevicesManager devices;
  
  // Debounce timer for validations
  Timer? _debounceTimer;

  BibNumberController({
    required this.context,
    required this.runners,
    required this.scrollController,
    required this.devices,
  });

  /// Gets a runner by bib number if it exists in the list of runners
  RunnerRecord? getRunnerByBib(String bib) {
    for (final runner in runners) {
      if (runner.bib == bib) {
        return runner;
      }
    }
    return null;
  }

  // Bib number validation and handling
  Future<void> validateBibNumber(
      int index, String bibNumber, List<double>? confidences) async {
    // If the index is out of bounds, don't try to validate
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    if (index < 0 || index >= provider.bibRecords.length) {
      return;
    }

    // Get the record to update
    final record = provider.bibRecords[index];
    
    // Special handling for empty inputs
    if (bibNumber.isEmpty) {
      record.name = '';
      record.school = '';
      record.flags = const RunnerRecordFlags(
        notInDatabase: false,
        duplicateBibNumber: false,
        lowConfidenceScore: false,
      );
      provider.updateBibRecord(index, record);
      return;
    }

    // Try to parse the bib number
    if (!bibNumber.contains(RegExp(r'^[0-9]+$'))) {
      // Not a valid number
      record.name = '';
      record.school = '';
      record.flags = RunnerRecordFlags(
        notInDatabase: true,
        duplicateBibNumber: false,
        lowConfidenceScore: confidences != null && 
            confidences.any((score) => score < 0.85),
      );
      provider.updateBibRecord(index, record);
      return;
    }

    // Check for a matching runner
    RunnerRecord? matchedRunner = getRunnerByBib(bibNumber);
    
    if (matchedRunner != null) {
      // Found a match in database
      record.name = matchedRunner.name;
      record.school = matchedRunner.school;
      record.grade = matchedRunner.grade;
      record.raceId = matchedRunner.raceId;
      
      // Check for duplicate entries
      bool isDuplicate = false;
      int count = 0;
      for (var i = 0; i < provider.bibRecords.length; i++) {
        if (provider.bibRecords[i].bib == bibNumber) {
          count++;
          if (count > 1 && i == index) {
            isDuplicate = true;
            break;
          }
        }
      }
      
      record.flags = RunnerRecordFlags(
        notInDatabase: false,
        duplicateBibNumber: isDuplicate,
        lowConfidenceScore: confidences != null && 
            confidences.any((score) => score < 0.85),
      );
      
      print('Runner found: $matchedRunner');
    } else {
      // No match in database
      record.name = '';
      record.school = '';
      record.grade = -1;
      record.raceId = -1;
      record.flags = RunnerRecordFlags(
        notInDatabase: true,
        duplicateBibNumber: false,
        lowConfidenceScore: confidences != null && 
            confidences.any((score) => score < 0.85),
      );
    }
    
    // Update the bib record with the runner information
    provider.updateBibRecord(index, record);
  }

  void onBibRecordRemoved(int index) {
    Provider.of<BibRecordsProvider>(context, listen: false)
        .removeBibRecord(index);
  }

  /// Handles bib number changes with optimizations to prevent UI jumping
  Future<void> handleBibNumber(
    String bibNumber, {
    List<double>? confidences,
    int? index,
  }) async {
    // Cancel any pending debounce timer
    _debounceTimer?.cancel();
    
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);

    if (index != null) {
      // Update existing record (immediately update the text but debounce validation)
      if (index < provider.bibRecords.length) {
        final record = provider.bibRecords[index];
        
        // Update text immediately without revalidating
        record.bib = bibNumber;
        provider.updateBibRecord(index, record);
        
        // Debounce the validation to prevent rapid UI updates while typing
        _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
          // Only validate if we still have focus to prevent unnecessary updates
          if (provider.focusNodes.length > index && 
              provider.focusNodes[index].hasFocus) {
            await validateBibNumber(index, bibNumber, confidences);
          }
        });
      }
    } else {
      // Add new record
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
      
      // Scroll to bottom when adding new bib (but after animation completes)
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
      
      // After adding a new record, we don't need to immediately validate
      _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
        final newIndex = provider.bibRecords.length - 1;
        if (newIndex >= 0) {
          await validateBibNumber(newIndex, bibNumber, confidences);
        }
      });
    }

    // We don't want to revalidate all items on every keystroke
    // Only do this on explicit user actions like adding/removing items
    if (index == null) {
      // Validate all bib numbers to update duplicate states after a delay
      _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
        for (var i = 0; i < provider.bibRecords.length; i++) {
          if (i != index) { // Skip the one we're currently editing
            await validateBibNumber(
                i, provider.bibRecords[i].bib, i == index ? confidences : null);
          }
        }
      });
    }

    if (runners.isNotEmpty && index == null) {
      // Safely determine focus index for new additions
      final focusIndex = provider.bibRecords.length - 1;
      
      // Only request focus if the index is valid
      if (focusIndex >= 0 && focusIndex < provider.focusNodes.length) {
        // Request focus after a slight delay to allow the UI to settle
        WidgetsBinding.instance.addPostFrameCallback((_) {
          provider.focusNodes[focusIndex].requestFocus();
        });
      }
    }
  }

  void scrollToBottom() {
    if (scrollController.hasClients) {
      // Use a safe scroll position calculation
      final scrollPosition = scrollController.position.maxScrollExtent;
      
      // Add padding to ensure the bottom item is fully visible
      final targetPosition = scrollPosition + 100;
      
      scrollController.animateTo(
        targetPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      // Try again in the next frame if the scroll controller is not ready
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
    }
  }

  /// Restores the focus abilities for all focus nodes
  void restoreFocusability() {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    for (var node in provider.focusNodes) {
      node.canRequestFocus = true;
    }
  }

  /// Gets the encoded bib data for sharing
  String getEncodedBibData() {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final bibNumbers = provider.bibRecords.map((e) => e.bib).toList();
    return bibNumbers.join(',');
  }

  /// Returns all unique bib numbers and the corresponding runner records
  Map<String, RunnerRecord> getBibsAndRunners() {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final map = <String, RunnerRecord>{};
    for (final record in provider.bibRecords) {
      if (record.bib.isNotEmpty) {
        map[record.bib] = record;
      }
    }
    return map;
  }

  Future<bool> checkDuplicateRecords() async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final records = provider.bibRecords;

    // Find all duplicate bib numbers
    final duplicates = <String>{};
    final seen = <String>{};

    for (final record in records) {
      final bib = record.bib;
      if (bib.isEmpty) continue;

      if (seen.contains(bib)) {
        duplicates.add(bib);
      } else {
        seen.add(bib);
      }
    }

    if (duplicates.isEmpty) {
      return true;
    }

    return await DialogUtils.showConfirmationDialog(
      context,
      title: 'Duplicate Bib Numbers',
      content: 'There are duplicate bib numbers in the list: ${duplicates.join(', ')}. Do you want to continue?',
    );
  }

  Future<bool> checkUnknownRecords() async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final records = provider.bibRecords;

    bool hasUnknown = false;
    for (final record in records) {
      if (record.flags.notInDatabase) {
        hasUnknown = true;
        break;
      }
    }

    if (!hasUnknown) {
      return true;
    }

    return await DialogUtils.showConfirmationDialog(
      context,
      title: 'Unknown Bib Numbers',
      content: 'There are bib numbers in the list that do not match any runners in the database. Do you want to continue?',
    );
  }

  Future<bool> cleanEmptyRecords() async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final emptyRecords =
        provider.bibRecords.where((bib) => bib.bib.isEmpty).toList();

    for (var i = emptyRecords.length - 1; i >= 0; i--) {
      final index = provider.bibRecords.indexOf(emptyRecords[i]);
      if (index >= 0) {
        provider.removeBibRecord(index);
      }
    }
    return true;
  }
}
