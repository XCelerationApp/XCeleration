import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'google_drive_service.dart';
import 'file_utils.dart';

/// Process a spreadsheet for runner data, either from local storage or Google Drive
/// Uses the modern GoogleDriveService with drive.file scope for Google Drive operations
Future<List<Map<String, dynamic>>> processSpreadsheet(BuildContext context,
    {bool useGoogleDrive = false}) async {
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
      result = await DialogUtils.executeWithLoadingDialog<
          List<Map<String, dynamic>>>(context, operation: () async {
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
    Logger.e('Error processing spreadsheet: $e');
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
List<Map<String, dynamic>> _processSpreadsheetData(List<List<dynamic>> data) {
  final List<Map<String, dynamic>> runnerData = [];

  // Remove empty cells (commas) and ignore empty lines entirely
  List<String> sanitizeRow(List<dynamic> row) {
    return row
        .map((cell) => (cell?.toString() ?? '').replaceAll('"', '').trim())
        .where((cell) => cell.isNotEmpty)
        .toList();
  }

  // Determine if the first row is a header (all text, no digits)
  bool isHeaderRow(List<dynamic> row) {
    final cleaned = sanitizeRow(row);
    // Consider a cell as "text" if it contains no digits
    bool cellIsText(dynamic cell) {
      final str = cell?.toString() ?? '';
      return str.isNotEmpty && !RegExp(r'\d').hasMatch(str);
    }

    // Header row if all first 3 cells are text and not empty
    return cleaned.length >= 3 &&
        cellIsText(cleaned[0]) &&
        cellIsText(cleaned[1]) &&
        cellIsText(cleaned[2]);
  }

  int startIdx = 0;
  if (data.isNotEmpty && isHeaderRow(data[0])) {
    startIdx = 1;
  }

  for (int i = startIdx; i < data.length; i++) {
    final originalRow = data[i];
    final row = sanitizeRow(originalRow);

    // Skip empty lines after sanitization
    if (row.isEmpty) {
      continue;
    }

    // Ensure the row contains at least [name, grade, bib]
    if (row.length >= 3) {
      // Parse the row data
      final String name = row[0];

      // Handle grade which may be an int, double, or string
      int grade = 0;
      final String rawGradeStr = row[1];
      final num? rawGradeNum = num.tryParse(rawGradeStr);
      if (rawGradeNum != null) {
        grade = rawGradeNum.round();
      } else {
        grade = int.tryParse(rawGradeStr) ??
            (double.tryParse(rawGradeStr)?.round() ?? 0);
      }

      // Handle bib number which may come back with a trailing decimal (e.g. 1.0)
      String bibNumber = row[2];
      if (bibNumber.contains('.') && double.tryParse(bibNumber) != null) {
        bibNumber = double.parse(bibNumber).toInt().toString();
      }

      final int bibNumberInt = int.tryParse(bibNumber) ?? -1;

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
        Logger.d('Invalid data in row (after sanitize): $row');
      }
    } else {
      Logger.d('Incomplete row (after sanitize): $row');
    }
  }

  return runnerData;
}
