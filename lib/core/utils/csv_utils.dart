import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xceleration/core/utils/logger.dart';

class CsvUtils {
  // Generate CSV content based on the provided data
  static String generateCsvContent({
    required bool isHeadToHead,
    required List<Map<String, dynamic>> teamResults,
    required List<Map<String, dynamic>> individualResults,
  }) {
    List<List<dynamic>> rows = [];
    if (isHeadToHead) {
      // Head-to-Head Results
      rows.add(['Team 1', 'Score', 'Time', 'Team 2', 'Score', 'Time']);
      for (var matchup in teamResults) {
        rows.add([
          matchup['team1']?['team'] ?? 'Unknown Team',
          matchup['team1']?['score']?.toString() ?? 'N/A',
          matchup['team1']?['times'] ?? 'N/A',
          matchup['team2']?['team'] ?? 'Unknown Team',
          matchup['team2']?['score']?.toString() ?? 'N/A',
          matchup['team2']?['times'] ?? 'N/A',
        ]);
      }
    } else {
      // Overall Results
      rows.add(['Place', 'Team', 'Score', 'Scorers', 'Times']);
      for (var team in teamResults) {
        rows.add([
          team['place']?.toString() ?? 'N/A',
          team['team'] ?? 'Unknown Team',
          team['score']?.toString() ?? 'N/A',
          team['scorers'] ?? 'N/A',
          team['times'] ?? 'N/A',
        ]);
      }
    }

    // Individual Results
    rows.add([]); // Add empty row as separator
    rows.add(['Individual Results']);
    rows.add(['Place', 'Name', 'Grade', 'Team', 'Time', 'Bib Number']);
    for (int i = 0; i < individualResults.length; i++) {
      var runner = individualResults[i];
      rows.add([
        (i + 1).toString(),
        runner['name'] ?? 'Unknown Runner',
        runner['grade']?.toString() ?? 'N/A',
        runner['team'] ?? 'Unknown Team',
        runner['finish_time'] ?? 'N/A',
        runner['bib_number'] ?? 'N/A',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  // Save the generated CSV content using file_saver (cross-platform)
  static Future<String> saveCsvWithFileSaver(
      String filename, String csvContent) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        // Create the file in the selected directory
        final file = File('$selectedDirectory/$filename');
        await file.writeAsString(csvContent);
        Logger.d('File saved at: ${file.path}');
        return file.path;
      } else {
        Logger.d('Directory selection was canceled.');
        return '';
      }
    } catch (e) {
      throw Exception('Failed to save CSV with FileSaver: $e');
    }
  }
}
