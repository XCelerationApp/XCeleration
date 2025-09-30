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

  String cellToString(dynamic cell) {
    return (cell?.toString() ?? '').replaceAll('"', '').trim();
  }

  // Only used for heuristic fallback and quick checks
  List<String> sanitizeRow(List<dynamic> row) {
    return row
        .map((cell) => cellToString(cell))
        .where((cell) => cell.isNotEmpty)
        .toList();
  }

  // Detect header indices for known schema
  int idxBib = -1;
  int idxFirst = -1;
  int idxLast = -1;
  int idxFullName = -1; // e.g., "First Last" or "Name"
  int idxYear = -1;
  int idxGender = -1;

  bool hasHeader = false;
  if (data.isNotEmpty) {
    final header = data.first.map(cellToString).toList();
    final lower = header.map((h) => h.toLowerCase()).toList();

    idxBib = lower.indexWhere((h) => h.contains('athlete') && h.contains('#'));
    if (idxBib == -1) {
      idxBib =
          lower.indexWhere((h) => h == '#' || h == 'bib' || h == 'bib number');
    }
    idxFirst = lower.indexWhere((h) => h == 'first' || h == 'first name');
    idxLast = lower.indexWhere((h) => h == 'last' || h == 'last name');
    // Combined name column (support headers like "First Last", "Name", "Full Name", etc.)
    idxFullName = lower.indexWhere(
        (h) => (h.contains('first') && h.contains('last')) || h == 'name');
    if (idxFullName == -1) {
      idxFullName = lower.indexWhere((h) =>
          h.contains('full name') ||
          h.contains('athlete name') ||
          h.contains('runner name'));
    }
    idxYear = lower.indexWhere((h) => h == 'year' || h.contains('grade'));
    idxGender =
        lower.indexWhere((h) => h == 'm/f' || h == 'gender' || h == 'sex');

    // Heuristic: if there are multiple 'first' columns, try to infer which is full name
    // by sampling the first few data rows and counting presence of spaces.
    if (idxFullName == -1) {
      final List<int> firstCandidates = [];
      for (int i = 0; i < lower.length; i++) {
        if (lower[i].contains('first')) firstCandidates.add(i);
      }
      if (firstCandidates.length > 1) {
        int bestIdx = -1;
        int bestSpaceCount = -1;
        int bestSingleCount = -1;
        int altIdx = -1;
        final int sampleStart = 1;
        final int sampleEnd =
            data.length < 11 ? data.length : 11; // up to 10 rows
        for (final idx in firstCandidates) {
          int spaceCount = 0;
          int singleCount = 0;
          for (int r = sampleStart; r < sampleEnd; r++) {
            final cell =
                (idx < data[r].length) ? cellToString(data[r][idx]) : '';
            if (cell.isEmpty) continue;
            if (cell.contains(' ')) {
              spaceCount++;
            } else {
              singleCount++;
            }
          }
          if (spaceCount > bestSpaceCount) {
            bestSpaceCount = spaceCount;
            bestSingleCount = singleCount;
            bestIdx = idx;
          } else if (spaceCount == bestSpaceCount &&
              singleCount > bestSingleCount) {
            // tie-breaker
            bestSingleCount = singleCount;
            bestIdx = idx;
          }
        }
        if (bestIdx != -1 && bestSpaceCount > 0) {
          idxFullName = bestIdx;
          // Choose a different candidate as first name if possible
          for (final idx in firstCandidates) {
            if (idx != bestIdx) {
              altIdx = idx;
              break;
            }
          }
          if (altIdx != -1 && idxFirst == -1) {
            idxFirst = altIdx;
          }
        }
      }
    }

    hasHeader = idxBib != -1 &&
        idxYear != -1 &&
        (idxFullName != -1 || idxFirst != -1 || idxLast != -1);
  }

  int startIdx = hasHeader ? 1 : 0;

  int parseYearToGrade(String raw) {
    if (raw.isEmpty) return 0;
    final s = raw.toLowerCase().trim();
    // handle numeric like 9, 9th, 10th, 11, 12, etc
    final match = RegExp(r'\d+').firstMatch(s);
    if (match != null) {
      final g = int.tryParse(match.group(0)!) ?? 0;
      if (g >= 9 && g <= 12) return g;
    }
    // Common words and abbreviations
    if (s == 'fr' || s.contains('fresh') || s.contains('frosh')) return 9;
    if (s == 'so' || s.contains('soph')) return 10; // sophomore
    if (s == 'jr' || s.contains('junior')) return 11;
    if (s == 'sr' || s.contains('senior')) return 12;
    return 0;
  }

  String normalizeBib(String raw) {
    var b = raw.trim();
    if (b.isEmpty) return '';
    b = b.replaceAll(RegExp(r'[^0-9\.]'), '');
    if (b.contains('.') && double.tryParse(b) != null) {
      b = double.parse(b).toInt().toString();
    }
    // Convert to int and back to strip leading zeros
    final asInt = int.tryParse(b);
    return asInt?.toString() ?? '';
  }

  for (int i = startIdx; i < data.length; i++) {
    final rowRaw = data[i];

    if (rowRaw.isEmpty || rowRaw.every((c) => cellToString(c).isEmpty)) {
      continue;
    }

    String name = '';
    int grade = 0;
    String bibNumber = '';
    String? gender; // 'M' or 'F'

    if (hasHeader) {
      final fullName = (idxFullName >= 0 && idxFullName < rowRaw.length)
          ? cellToString(rowRaw[idxFullName])
          : '';
      final first = (idxFirst >= 0 && idxFirst < rowRaw.length)
          ? cellToString(rowRaw[idxFirst])
          : '';
      final last = (idxLast >= 0 && idxLast < rowRaw.length)
          ? cellToString(rowRaw[idxLast])
          : '';
      final yearStr = (idxYear >= 0 && idxYear < rowRaw.length)
          ? cellToString(rowRaw[idxYear])
          : '';
      final bibStr = (idxBib >= 0 && idxBib < rowRaw.length)
          ? cellToString(rowRaw[idxBib])
          : '';
      final genderStr = (idxGender >= 0 && idxGender < rowRaw.length)
          ? cellToString(rowRaw[idxGender])
          : '';

      // Prefer a combined name if it clearly includes both parts; otherwise, build from separate columns
      if (fullName.isNotEmpty && fullName.contains(' ')) {
        name = fullName.trim();
      } else {
        name = [first, last].where((p) => p.isNotEmpty).join(' ').trim();
        if (name.isEmpty && fullName.isNotEmpty) {
          // Fallback: some sheets mislabel columns; use whatever is there
          name = fullName.trim();
        }
      }
      grade = parseYearToGrade(yearStr);
      bibNumber = normalizeBib(bibStr);

      if (genderStr.isNotEmpty) {
        final g = genderStr.toUpperCase();
        if (g.startsWith('M')) gender = 'M';
        if (g.startsWith('F')) gender = 'F';
      }
    } else {
      // Fallback heuristic: [name, grade/year, bib]
      final row = sanitizeRow(rowRaw);
      if (row.length < 3) {
        Logger.d('Incomplete row (after sanitize): $row');
        continue;
      }
      name = row[0];
      grade = parseYearToGrade(row[1]);
      bibNumber = normalizeBib(row[2]);
    }

    final bibInt = int.tryParse(bibNumber) ?? -1;
    if (name.isNotEmpty && grade >= 9 && grade <= 12 && bibInt >= 0) {
      runnerData.add({
        'name': name,
        'grade': grade,
        'bib': bibNumber,
        if (gender != null) 'gender': gender,
      });
    } else {
      Logger.d(
          'Invalid data in row: i=$i name="$name" grade=$grade bib="$bibNumber"');
    }
  }

  return runnerData;
}
