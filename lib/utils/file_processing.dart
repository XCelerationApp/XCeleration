import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'google_drive_service.dart';
import 'file_utils.dart';

/// Process a spreadsheet for runner data, either from local storage or Google Drive
/// Uses the modern GoogleDriveService with drive.file scope for Google Drive operations
Future<List<RunnerRecord>> processSpreadsheet(int raceId, bool isTeam, {BuildContext? context, bool useGoogleDrive = false}) async {
  // Check if we have a context
  if (context == null) {
    Logger.d('Context is required for file operations');
    return [];
  }
  
  File? selectedFile;
  
  try {
    if (useGoogleDrive) {
      // Use Google Drive picker with drive.file scope
      selectedFile = await GoogleDriveService.instance.pickSpreadsheetFile(context);
    } else {
      // Use local file picker with loading dialog
      selectedFile = await FileUtils.pickLocalSpreadsheetFile();
    }
    
    // Check if user cancelled or error occurred
    if (selectedFile == null) return [];
    
    // Process the spreadsheet with loading dialog
    if (!context.mounted) return [];
    final result = await DialogUtils.executeWithLoadingDialog<List<RunnerRecord>>(
      context,
      operation: () async {
        final parsedData = await FileUtils.parseSpreadsheetFile(selectedFile!);
        
        // Check if we got valid data
        if (parsedData == null || parsedData.isEmpty) {
          if (context.mounted) {
            DialogUtils.showErrorDialog(
              context, 
              message: 'Invalid Spreadsheet: The selected file does not contain valid spreadsheet data.'
            );
          }
          return [];
        }
        
        return _processSpreadsheetData(parsedData, raceId, isTeam);
      },
      loadingMessage: 'Processing spreadsheet...'
    );
    
    // Return the result or empty list if null
    return result ?? [];
    
  } catch (e) {
    Logger.d('Error processing spreadsheet: $e');
    if (context.mounted) {
      DialogUtils.showErrorDialog(
        context, 
        message: 'File Selection Error: An error occurred while selecting or processing the file: ${e.toString()}'
      );
    }
    return [];
  }
}

/// Convert spreadsheet data to runner records
List<RunnerRecord> _processSpreadsheetData(
    List<List<dynamic>> data, 
    int raceId, 
    bool isTeam) {
  final List<RunnerRecord> runnerData = [];
  
  // Skip header row
  for (int i = 1; i < data.length; i++) {
    final row = data[i];
    
    // Ensure the row is not empty and contains the required columns
    if (row.isNotEmpty && row.length >= 4) {
      // Parse the row data
      String name = row[0]?.toString() ?? '';
      int grade = int.tryParse(row[1]?.toString() ?? '') ?? 0;
      String school = row[2]?.toString() ?? '';
      String bibNumber = row[3]?.toString().replaceAll('"', '') ?? '';
      int bibNumberInt = int.tryParse(bibNumber) ?? -1;
      
      // Validate the parsed data
      if (name.isNotEmpty &&
          grade > 0 &&
          school.isNotEmpty &&
          bibNumber.isNotEmpty &&
          bibNumberInt >= 0) {
        if (isTeam) {
          runnerData.add(RunnerRecord(
            name: name,
            school: school,
            grade: grade,
            bib: bibNumber,
            runnerId: -1,
            raceId: raceId,
          ));
        } else {
          runnerData.add(RunnerRecord(
            name: name,
            school: school,
            grade: grade,
            bib: bibNumber,
            runnerId: -1,
            raceId: raceId,
          ));
        }
      } else {
        Logger.d('Invalid data in row: $row');
      }
    } else if (row.isNotEmpty) {
      Logger.d('Incomplete row: $row');
    }
  }
  
  return runnerData;
}
