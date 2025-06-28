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
    Logger.d('Parsing file: ${file.path}');

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
          if (rowData
              .any((cell) => cell != null && cell.toString().isNotEmpty)) {
            data.add(rowData);
          }
        }

        return data;
      } else if (extension == '.csv') {
        // Parse CSV file with enhanced options
        return await _parseCSVFile(file);
      } else {
        Logger.d('Unsupported file format: $extension');
        return null;
      }
    } catch (e) {
      Logger.d('Error parsing spreadsheet: $e');
      return null;
    }
  }

  /// Enhanced CSV parsing with options for different delimiters, quote chars, etc.
  static Future<List<List<dynamic>>> _parseCSVFile(File file) async {
    final contents = await file.readAsString();
    Logger.d('Parsing CSV file: $contents');

    try {
      // Try to detect the delimiter (common ones are comma, tab, semicolon)
      String delimiter = ','; // Default
      if (contents.contains('\t')) {
        // Check if tab-delimited
        final tabCount = '\t'.allMatches(contents).length;
        final commaCount = ','.allMatches(contents).length;
        if (tabCount > commaCount) delimiter = '\t';
      } else if (!contents.contains(',') && contents.contains(';')) {
        // European format often uses semicolons
        delimiter = ';';
      }

      // Parse with detected delimiter
      final converter = CsvToListConverter(
        fieldDelimiter: delimiter,
        eol: '\n',
        shouldParseNumbers: true, // Convert strings to numbers when possible
      );

      final rows = converter.convert(contents);
      Logger.d('Parsed CSV file: $rows');
      // Remove empty rows
      return rows
          .where((row) =>
              row.isNotEmpty &&
              row.any((cell) => cell != null && cell.toString().isNotEmpty))
          .toList();
    } catch (e) {
      // If custom parsing fails, fall back to default parsing
      Logger.d(
          'Advanced CSV parsing failed: $e. Falling back to default parser.');
      return const CsvToListConverter().convert(contents);
    }
  }
}
