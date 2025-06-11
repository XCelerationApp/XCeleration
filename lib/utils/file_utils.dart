import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as path;
import 'package:xceleration/core/utils/logger.dart';

/// Utility class for file operations related to spreadsheets
class FileUtils {
  /// Pick a local spreadsheet file (Excel or CSV)
  static Future<File?> pickLocalSpreadsheetFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        Logger.d('No file selected');
        return null;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        Logger.d('Invalid file path');
        return null;
      }

      return File(filePath);
    } catch (e) {
      Logger.d('Error picking local file: $e');
      return null;
    }
  }

  /// Parse a spreadsheet file (Excel or CSV) into a list of rows
  static Future<List<List<dynamic>>?> parseSpreadsheetFile(File file) async {
    final extension = path.extension(file.path).toLowerCase();
    
    try {
      if (extension == '.xlsx') {
        // Parse Excel file
        final bytes = await file.readAsBytes();
        final excel = Excel.decodeBytes(bytes);
        
        // Get the first sheet
        if (excel.tables.isEmpty) {
          Logger.d('Excel file contains no sheets');
          return null;
        }
        
        final sheet = excel.tables.values.first;
        final List<List<dynamic>> data = [];
        
        // Convert Excel rows to list format
        for (var row in sheet.rows) {
          if (row.isEmpty) continue;
          
          final List<dynamic> rowData = [];
          for (var cell in row) {
            rowData.add(cell?.value ?? '');
          }
          
          // Only add if row has actual data
          if (rowData.any((cell) => cell != null && cell.toString().isNotEmpty)) {
            data.add(rowData);
          }
        }
        
        return data;
      } else if (extension == '.csv') {
        // Parse CSV file
        final contents = await file.readAsString();
        final rows = const CsvToListConverter().convert(contents);
        
        return rows;
      } else {
        Logger.d('Unsupported file format: $extension');
        return null;
      }
    } catch (e) {
      Logger.d('Error parsing spreadsheet: $e');
      return null;
    }
  }
}
