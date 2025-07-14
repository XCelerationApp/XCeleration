import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'google_drive_service.dart';
import 'file_utils.dart';

/// Process a spreadsheet for runner data, either from local storage or Google Drive
/// Uses the modern GoogleDriveService with drive.file scope for Google Drive operations
Future<List<Map<String, dynamic>>> processSpreadsheet(BuildContext context, {bool useGoogleDrive = false}) async {
  File? selectedFile;
  final navigatorContext = Navigator.of(context, rootNavigator: true).context;

  try {
    if (useGoogleDrive) {
      // Use Google Drive picker with drive.file scope
      selectedFile =
          await GoogleDriveService.instance.pickSpreadsheetFile(context);
    } else {
      // Use local file picker with loading dialog
      selectedFile = await FileUtils.pickLocalSpreadsheetFile();
    }

    // Check if user cancelled or error occurred
    if (selectedFile == null) {
      Logger.d('No file selected');
      return [];
    }

    Logger.d('File selected: ${selectedFile.path}');
    List<Map<String, dynamic>>? result;
    if (!context.mounted) context = navigatorContext;
    // Process the spreadsheet with loading dialog if context is mounted
    if (context.mounted) {
      result = await DialogUtils.executeWithLoadingDialog<List<Map<String, dynamic>>>(
          context, operation: () async {
        final parsedData = await FileUtils.parseSpreadsheetFile(selectedFile!);

        // Check if we got valid data
        if (parsedData == null || parsedData.isEmpty) {
          Logger.d(
              'Invalid Spreadsheet: The selected file does not contain valid spreadsheet data.');
          if (context.mounted) {
            DialogUtils.showErrorDialog(context,
                message:
                    'Invalid Spreadsheet: The selected file does not contain valid spreadsheet data.');
          }
          return [];
        }

        return _processSpreadsheetData(parsedData);
      }, loadingMessage: 'Processing spreadsheet...');
    } else {
      // If context is not mounted, process without loading dialog
      Logger.d('Context not mounted, processing without loading dialog');
      final parsedData = await FileUtils.parseSpreadsheetFile(selectedFile);
      Logger.d('Parsed data: $parsedData');

      // Check if we got valid data
      if (parsedData == null || parsedData.isEmpty) {
        Logger.d(
            'Invalid Spreadsheet: The selected file does not contain valid spreadsheet data.');
        return [];
      }

      result = _processSpreadsheetData(parsedData);
      Logger.d('Result: $result');
    }

    if (result == null) {
      Logger.d('No data returned from spreadsheet processing');
      return [];
    }

    // Return the result or empty list if null
    return result;
  } catch (e) {
    Logger.d('Error processing spreadsheet: $e');
    if (!context.mounted) context = navigatorContext;
    if (context.mounted) {
      DialogUtils.showErrorDialog(context,
          message:
              'File Selection Error: An error occurred while selecting or processing the file: ${e.toString()}');
    }
    return [];
  }
}

/// Process the spreadsheet data to get the runner data
List<Map<String, dynamic>> _processSpreadsheetData(
    List<List<dynamic>> data) {
  final List<Map<String, dynamic>> runnerData = [];

  // Skip header row
  for (int i = 1; i < data.length; i++) {
    final row = data[i];

    // Ensure the row is not empty and contains the required columns
    if (row.isNotEmpty && row.length >= 3) {
      // Parse the row data
      String name = row[0]?.toString() ?? '';
      // Handle grade which may be an int, double, or string
      int grade = 0;
      final dynamic rawGrade = row[1];
      if (rawGrade is num) {
        grade = rawGrade.round();
      } else {
        grade = int.tryParse(rawGrade?.toString().trim() ?? '') ??
            (double.tryParse(rawGrade?.toString().trim() ?? '')?.round() ?? 0);
      }

      // Handle bib number which may come back as a numeric type with a trailing decimal (e.g. 1.0)
      String bibNumber;
      final dynamic rawBib = row[2];
      if (rawBib is num) {
        bibNumber = rawBib.toInt().toString();
      } else {
        bibNumber = rawBib?.toString().trim().replaceAll('"', '') ?? '';
        // If bibNumber still contains a decimal point like '1.0', strip it
        if (bibNumber.contains('.') && double.tryParse(bibNumber) != null) {
          bibNumber = double.parse(bibNumber).toInt().toString();
        }
      }

      int bibNumberInt = int.tryParse(bibNumber) ?? -1;

      // Validate the parsed data
      if (name.isNotEmpty &&
          grade > 0 &&
          bibNumber.isNotEmpty &&
          bibNumberInt >= 0) {
        runnerData.add({
          'name': name,
          'grade': grade,
          'bib': bibNumber,
        });
      } else {
        Logger.d('Invalid data in row: $row');
      }
    } else if (row.isNotEmpty) {
      Logger.d('Incomplete row: $row');
    }
  }

  return runnerData;
}
