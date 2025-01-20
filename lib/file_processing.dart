import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
// import 'dart:convert';
import 'dart:io';
import 'package:race_timing_app/database_helper.dart';


Future<void> processSpreadsheet(int raceId, bool shared) async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv', 'xlsx'],
  );

  if (result != null) {
    final file = File(result.files.first.path!);
    final extension = result.files.first.extension;

    if (extension == 'csv') {
      // Process CSV file
      final csvContent = await file.readAsString();
      List<List<dynamic>> rows = const CsvToListConverter().convert(csvContent);

      for (var row in rows) {
        if (row.isNotEmpty && row.length >= 4) {
          String name = row[0]?.toString() ?? '';
          int grade = int.tryParse(row[1]?.toString() ?? '') ?? 0;
          String school = row[2]?.toString() ?? '';
          String bibNumber = row[3]?.toString().replaceAll('"', '') ?? ''; // Remove quotation marks if present
          int bibNumberInt = int.tryParse(bibNumber) ?? -1;
          // print("bibNumberInt:");
          // print(bibNumberInt);

          if (name.isNotEmpty && grade > 0 && school.isNotEmpty && bibNumber.isNotEmpty && bibNumberInt >= 0) {
            if (shared == true) {
              await DatabaseHelper.instance.insertSharedRunner({
                'name': name,
                'school': school,
                'grade': grade,
                'bib_number': bibNumber,
              });
            } else {
              await DatabaseHelper.instance.insertRaceRunner({
                'name': name,
                'school': school,
                'grade': grade,
                'bib_number': bibNumberInt,
                'race_id': raceId,
              });
            } 
          } else {
            print('Invalid data in row: $row');
          }
        } else {
          print('Incomplete row: $row');
        }
      }

    } else if (extension == 'xlsx') {
      // Process Excel file
      var bytes = file.readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      for (var table in excel.tables.keys) {
        for (var row in excel.tables[table]!.rows) {
          // Ensure the row is not empty and contains the required number of columns
          if (row.isNotEmpty && row.length >= 4) {
            // Parse the row data
            String name = row[0]?.toString() ?? '';
            int grade = int.tryParse(row[1]?.toString() ?? '') ?? 0;
            String school = row[2]?.toString() ?? '';
            String bibNumber = row[3]?.toString().replaceAll('"', '') ?? ''; // Remove quotation marks if present
            int bibNumberInt = int.tryParse(bibNumber) ?? -1;
            // print("bibNumberInt:");
            // print(bibNumberInt);

            // Validate the parsed data
            if (name.isNotEmpty && grade > 0 && school.isNotEmpty && bibNumberInt >= 0 && bibNumber.isNotEmpty) {
              // Insert into the database
              if (shared == true) {
                await DatabaseHelper.instance.insertSharedRunner({
                  'name': name,
                  'school': school,
                  'grade': grade,
                  'bib_number': bibNumber,
                });
              } else {
                await DatabaseHelper.instance.insertRaceRunner({
                  'name': name,
                  'school': school,
                  'grade': grade,
                  'bib_number': bibNumberInt,
                  'race_id': raceId,
                });
              } 
            } else {
              print('Invalid data in row: $row');
            }
          } else {
            print('Incomplete row: $row');
          }
        }
      }

    } else {
      print('Unsupported file format: $extension');
    }
  } else {
    print('No file selected.');
  }
}
