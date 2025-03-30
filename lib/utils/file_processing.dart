import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';

Future<List<RunnerRecord>> processSpreadsheet(int raceId, bool isTeam) async {
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
