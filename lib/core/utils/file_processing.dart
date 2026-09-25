import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'google_drive_service.dart';
import 'file_utils.dart';
import 'recent_local_spreadsheet_service.dart';

/// Runner rows read from a spreadsheet, and the rows that were left out.
class SpreadsheetRows {
  /// Valid rows, each with keys name, grade, bib, and optionally gender and
  /// team (the team's name as the spreadsheet gives it).
  final List<Map<String, dynamic>> runners;

  /// One description per row that was left out, e.g.
  /// 'Row 4 (Jane Doe): grade "K" is not 9–12'.
  final List<String> skipped;

  const SpreadsheetRows(this.runners, [this.skipped = const []]);

  static const empty = SpreadsheetRows([]);
}

/// Rows a spreadsheet lost before it became a file, such as those left out
/// when several Google Sheet tabs were combined. Reported with the next
/// import's own skipped rows, then forgotten.
List<String> _skippedBeforeFile = const [];

/// Records rows left out while preparing the file about to be imported.
void noteRowsSkippedBeforeFile(List<String> rows) => _skippedBeforeFile = rows;

SpreadsheetRows _withSkippedBeforeFile(SpreadsheetRows rows) {
  final earlier = _skippedBeforeFile;
  _skippedBeforeFile = const [];
  if (earlier.isEmpty) return rows;
  return SpreadsheetRows(rows.runners, [...earlier, ...rows.skipped]);
}

/// Processes an already-downloaded [file] through the spreadsheet pipeline
/// (parse → validate → extract runner rows). Used for the "Recent Spreadsheets"
/// flow where the file has already been downloaded before this call.
Future<SpreadsheetRows> processSpreadsheetFromFile(
    BuildContext context, File file) async {
  final navigatorContext = Navigator.of(context, rootNavigator: true).context;
  try {
    BuildContext ctx = context.mounted ? context : navigatorContext;
    SpreadsheetRows? result;
    if (ctx.mounted) {
      result = await DialogUtils.executeWithLoadingDialog<SpreadsheetRows>(ctx, operation: () async {
        final parsedData = await FileUtils.parseSpreadsheetFile(file);
        if (parsedData == null || parsedData.isEmpty) {
          if (ctx.mounted) {
            DialogUtils.showErrorDialog(ctx,
                message:
                    'Invalid Spreadsheet: The selected file does not contain valid spreadsheet data.');
          }
          return SpreadsheetRows.empty;
        }
        return processSpreadsheetData(parsedData);
      }, loadingMessage: 'Processing spreadsheet...');
    } else {
      final parsedData = await FileUtils.parseSpreadsheetFile(file);
      if (parsedData == null || parsedData.isEmpty) {
        return SpreadsheetRows.empty;
      }
      result = processSpreadsheetData(parsedData);
    }
    return _withSkippedBeforeFile(result ?? SpreadsheetRows.empty);
  } catch (e) {
    Logger.e('Error processing spreadsheet file: $e');
    final ctx =
        context.mounted ? context : navigatorContext;
    if (ctx.mounted) {
      DialogUtils.showErrorDialog(ctx,
          message:
              'File Selection Error: An error occurred while processing the file: ${e.toString()}');
    }
    return SpreadsheetRows.empty;
  }
}

/// Process a spreadsheet for runner data, either from local storage or Google Drive
/// Uses the modern GoogleDriveService with drive.file scope for Google Drive operations
Future<SpreadsheetRows> processSpreadsheet(BuildContext context,
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
      if (selectedFile != null) {
        // Record in recents after a successful local pick.
        final name = selectedFile.uri.pathSegments.last;
        await RecentLocalSpreadsheetService.instance
            .record(name, selectedFile.path);
      }
    }

    // Check if user cancelled or error occurred
    if (selectedFile == null) {
      Logger.d('No file selected');
      return SpreadsheetRows.empty;
    }

    Logger.d('File selected: ${selectedFile.path}');
    SpreadsheetRows? result;
    if (!context.mounted) context = navigatorContext;
    // Process the spreadsheet with loading dialog if context is mounted
    if (context.mounted) {
      result = await DialogUtils.executeWithLoadingDialog<SpreadsheetRows>(context, operation: () async {
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
          return SpreadsheetRows.empty;
        }

        return processSpreadsheetData(parsedData);
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
        return SpreadsheetRows.empty;
      }

      result = processSpreadsheetData(parsedData);
      Logger.d('Result: $result');
    }

    if (result == null) {
      Logger.d('No data returned from spreadsheet processing');
      return SpreadsheetRows.empty;
    }

    return _withSkippedBeforeFile(result);
  } catch (e) {
    Logger.e('Error processing spreadsheet: $e');
    if (!context.mounted) context = navigatorContext;
    if (context.mounted) {
      DialogUtils.showErrorDialog(context,
          message:
              'File Selection Error: An error occurred while selecting or processing the file: ${e.toString()}');
    }
    return SpreadsheetRows.empty;
  }
}

/// Process the spreadsheet data to get the runner data. Rows that can't be
/// imported are listed in [SpreadsheetRows.skipped] rather than dropped
/// silently.
SpreadsheetRows processSpreadsheetData(List<List<dynamic>> data) {
  final List<Map<String, dynamic>> runnerData = [];
  final List<String> skipped = [];

  // Cells as the sheet shows them. The CSV reader already takes off the
  // quotes that wrap a cell; any left are part of the name, like "JJ".
  String cellToString(dynamic cell) => (cell?.toString() ?? '').trim();

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
  int idxTeam = -1;

  bool hasHeader = false;
  if (data.isNotEmpty) {
    final header = data.first.map(cellToString).toList();
    final lower = header.map((h) => h.toLowerCase()).toList();

    // "Athlete #", "Runner #" and the like.
    idxBib = lower.indexWhere((h) => h.length > 1 && h.endsWith('#'));
    if (idxBib == -1) {
      // "Bib", "Bib #", "Bib No.", "Bib Number", "#".
      idxBib = lower.indexWhere((h) =>
          h == '#' || h == 'bib' || h.startsWith('bib ') || h == 'bib#');
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
          h.contains('runner name') ||
          h == 'athlete' ||
          h == 'runner');
    }
    idxYear = lower.indexWhere((h) =>
        h == 'year' || h == 'yr' || h == 'class' || h.contains('grade'));
    idxGender =
        lower.indexWhere((h) => h == 'm/f' || h == 'gender' || h == 'sex');
    // Which team a runner is on, so a sheet of several teams can be imported
    // in one go.
    idxTeam = lower.indexWhere((h) =>
        h == 'team' ||
        h == 'team name' ||
        h == 'school' ||
        h == 'school name' ||
        h == 'club');

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

  /// The bib as printed. Leading zeros stay: a runner typed in by hand
  /// keeps "007", and the Bib Recorder's "007" has to match an imported
  /// runner the same way. A number cell's "12.0" is read as "12".
  String normalizeBib(String raw) {
    var b = raw.trim().replaceAll(RegExp(r'[^0-9\.]'), '');
    final wholeNumber = RegExp(r'^(\d+)\.0*$').firstMatch(b);
    if (wholeNumber != null) b = wholeNumber.group(1)!;
    return RegExp(r'^\d+$').hasMatch(b) ? b : '';
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
    String? team;

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

      final teamStr = (idxTeam >= 0 && idxTeam < rowRaw.length)
          ? cellToString(rowRaw[idxTeam])
          : '';
      if (teamStr.isNotEmpty) team = teamStr;

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
        skipped.add('Row ${i + 1}: needs a name, grade and bib number');
        continue;
      }
      name = row[0];
      grade = parseYearToGrade(row[1]);
      bibNumber = normalizeBib(row[2]);
    }

    final bibInt = int.tryParse(bibNumber) ?? -1;
    final String? problem = name.isEmpty
        ? 'no name'
        : !(grade >= 9 && grade <= 12)
            ? 'grade is not 9–12'
            : bibInt < 0
                ? 'bib is not a number'
                : null;
    if (problem == null) {
      runnerData.add({
        'name': name,
        'grade': grade,
        'bib': bibNumber,
        'gender': ?gender,
        'team': ?team,
      });
    } else {
      Logger.d(
          'Invalid data in row: i=$i name="$name" grade=$grade bib="$bibNumber"');
      skipped.add(
          'Row ${i + 1}${name.isNotEmpty ? ' ($name)' : ''}: $problem');
    }
  }

  return SpreadsheetRows(runnerData, skipped);
}
