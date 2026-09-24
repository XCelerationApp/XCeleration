import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show visibleForTesting;
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

  static Future<List<List<dynamic>>> _parseCSVFile(File file) async {
    return parseCsvText(decodeText(await file.readAsBytes()));
  }

  /// A text file's contents: UTF-8, or Windows' Latin-1 when it is not,
  /// as Excel saves CSV files on some computers.
  @visibleForTesting
  static String decodeText(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  /// Rows of a CSV file's text, every cell as written.
  ///
  /// Cells stay text: read as numbers, bib "007" became 7. A byte-order
  /// mark (Excel adds one) is dropped so the first heading is still found,
  /// Windows line endings are read as line endings, and tab- or
  /// semicolon-separated files are recognised.
  @visibleForTesting
  static List<List<dynamic>> parseCsvText(String text) {
    var contents = text.startsWith('\uFEFF') ? text.substring(1) : text;
    contents = contents.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    var delimiter = ',';
    final firstLine = contents.split('\n').first;
    final counts = {
      ',': ','.allMatches(firstLine).length,
      '\t': '\t'.allMatches(firstLine).length,
      ';': ';'.allMatches(firstLine).length,
    };
    final most = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    if (most.value > 0) delimiter = most.key;

    final rows = CsvToListConverter(
      fieldDelimiter: delimiter,
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(contents);
    return rows
        .where((row) =>
            row.isNotEmpty &&
            row.any((cell) => cell != null && cell.toString().trim().isNotEmpty))
        .toList();
  }
}
