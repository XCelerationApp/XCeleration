import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'google_drive_picker.dart';

Future<List<RunnerRecord>> processSpreadsheet(int raceId, bool isTeam, {BuildContext? context, bool useGoogleDrive = false}) async {
  // If Google Drive is selected, use the Google Drive file picker
  if (useGoogleDrive && context != null) {
    return processGoogleDriveSpreadsheet(context, raceId, isTeam);
  }
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv', 'xlsx'],
  );

  if (result != null) {
    final file = File(result.files.first.path!);
    final extension = result.files.first.extension;
    final List<RunnerRecord> runnerData = [];

    if (extension == 'csv') {
      // Process CSV file
      final csvContent = await file.readAsString();
      List<List<dynamic>> rows = const CsvToListConverter().convert(csvContent);

      for (var row in rows) {
        if (row == rows.first) continue;
        if (row.isNotEmpty && row.length >= 4) {
          String name = row[0]?.toString() ?? '';
          int grade = int.tryParse(row[1]?.toString() ?? '') ?? 0;
          String school = row[2]?.toString() ?? '';
          String bibNumber = row[3]?.toString().replaceAll('"', '') ??
              ''; // Remove quotation marks if present
          int bibNumberInt = int.tryParse(bibNumber) ?? -1;

          if (name.isNotEmpty &&
              grade > 0 &&
              school.isNotEmpty &&
              bibNumber.isNotEmpty &&
              bibNumberInt >= 0) {
            if (isTeam == true) {
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
                raceId: raceId,
                runnerId: -1,
              ));
            }
          } else {
            debugPrint('Invalid data in row: $row');
          }
        } else {
          debugPrint('Incomplete row: $row');
        }
      }
    } else if (extension == 'xlsx') {
      // Process Excel file
      var bytes = file.readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      for (var table in excel.tables.keys) {
        for (var row in excel.tables[table]!.rows) {
          if (row == excel.tables[table]!.rows.first) continue;
          // Ensure the row is not empty and contains the required number of columns
          if (row.isNotEmpty && row.length >= 4) {
            // Parse the row data
            String name = row[0]?.toString() ?? '';
            int grade = int.tryParse(row[1]?.toString() ?? '') ?? 0;
            String school = row[2]?.toString() ?? '';
            String bibNumber = row[3]?.toString().replaceAll('"', '') ??
                ''; // Remove quotation marks if present
            int bibNumberInt = int.tryParse(bibNumber) ?? -1;

            // Validate the parsed data
            if (name.isNotEmpty &&
                grade > 0 &&
                school.isNotEmpty &&
                bibNumberInt >= 0 &&
                bibNumber.isNotEmpty) {
              // Insert into the database
              if (isTeam == true) {
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
              debugPrint('Invalid data in row: $row');
            }
          } else {
            debugPrint('Incomplete row: $row');
          }
        }
      }
    } else {
      debugPrint('Unsupported file format: $extension');
    }
    return runnerData;
  } else {
    debugPrint('No file selected.');
    return [];
  }
}

/// Process a spreadsheet file from Google Drive
Future<List<RunnerRecord>> processGoogleDriveSpreadsheet(
    BuildContext context, int raceId, bool isTeam) async {
  try {
    // Use the improved Google Drive picker
    final GoogleDrivePicker picker = GoogleDrivePicker();
    final tempFile = await picker.pickFile(context, allowedExtensions: ['csv', 'xlsx']);
    
    if (tempFile == null) {
      debugPrint('No Google Drive file selected');
      return [];
    }
    
    final extension = tempFile.path.split('.').last.toLowerCase();
    final List<RunnerRecord> runnerData = [];
    
    if (extension == 'csv') {
      // Process CSV file
      final csvContent = await tempFile.readAsString();
      List<List<dynamic>> rows = const CsvToListConverter().convert(csvContent);

      for (var row in rows) {
        if (row == rows.first) continue;
        if (row.isNotEmpty && row.length >= 4) {
          String name = row[0]?.toString() ?? '';
          int grade = int.tryParse(row[1]?.toString() ?? '') ?? 0;
          String school = row[2]?.toString() ?? '';
          String bibNumber = row[3]?.toString().replaceAll('"', '') ?? 
              ''; // Remove quotation marks if present
          int bibNumberInt = int.tryParse(bibNumber) ?? -1;

          if (name.isNotEmpty &&
              grade > 0 &&
              school.isNotEmpty &&
              bibNumber.isNotEmpty &&
              bibNumberInt >= 0) {
            if (isTeam == true) {
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
                raceId: raceId,
                runnerId: -1,
              ));
            }
          } else {
            debugPrint('Invalid data in row: $row');
          }
        } else {
          debugPrint('Incomplete row: $row');
        }
      }
    } else if (extension == 'xlsx') {
      // Process Excel file
      var bytes = tempFile.readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      for (var table in excel.tables.keys) {
        for (var row in excel.tables[table]!.rows) {
          if (row == excel.tables[table]!.rows.first) continue;
          // Ensure the row is not empty and contains the required number of columns
          if (row.isNotEmpty && row.length >= 4) {
            // Parse the row data - handle both String and Data objects from Excel library
            String name = '';
            if (row[0] != null) {
              name = row[0] is String ? row[0] as String : (row[0]?.value?.toString() ?? '');
            }
            
            int grade = 0;
            if (row[1] != null) {
              var gradeStr = row[1] is String ? row[1] as String : (row[1]?.value?.toString() ?? '');
              // Handle floating point values like 11.0
              if (gradeStr.isNotEmpty) {
                if (gradeStr.contains('.')) {
                  grade = int.tryParse(gradeStr.split('.').first) ?? 0;
                } else {
                  grade = int.tryParse(gradeStr) ?? 0;
                }
              }
            }
            
            String school = '';
            if (row[2] != null) {
              school = row[2] is String ? row[2] as String : (row[2]?.value?.toString() ?? '');
            }
            
            String bibNumber = '';
            if (row[3] != null) {
              bibNumber = row[3] is String ? row[3] as String : (row[3]?.value?.toString() ?? '');
              bibNumber = bibNumber.replaceAll('"', ''); // Remove quotation marks if present
            }
            
            int bibNumberInt = int.tryParse(bibNumber) ?? -1;

            // Validate the parsed data
            if (name.isNotEmpty &&
                grade > 0 &&
                school.isNotEmpty &&
                bibNumberInt >= 0 &&
                bibNumber.isNotEmpty) {
              // Insert into the database
              if (isTeam == true) {
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
              debugPrint('Invalid data in row: $row');
            }
          } else {
            debugPrint('Incomplete row: $row');
          }
        }
      }
    } else {
      debugPrint('Unsupported file format: $extension');
    }
    
    // Delete the temporary file
    await tempFile.delete();
    
    return runnerData;
  } catch (e) {
    debugPrint('Error processing Google Drive spreadsheet: $e');
    return [];
  }
}
