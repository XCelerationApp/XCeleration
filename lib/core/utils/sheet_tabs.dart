import 'file_processing.dart';

/// Several tabs of one spreadsheet read as one roster.
class CombinedTabs {
  const CombinedTabs(this.rows, this.skipped);

  /// A header row (Bib, Name, Grade, Gender, Team), then one row per runner.
  final List<List<String>> rows;

  /// Rows left out, each with its tab: 'Drake, row 4 (Kid Tooyoung): …'.
  final List<String> skipped;
}

/// Reads each tab in [tabs] (tab name to its rows) and puts every runner
/// together. A runner with no team of their own takes the tab's name as
/// their team, so a spreadsheet with a tab per school imports each school as
/// a team. Each tab may have its own headings.
CombinedTabs combineTabs(Map<String, List<List<dynamic>>> tabs) {
  final rows = <List<String>>[
    ['Bib', 'Name', 'Grade', 'Gender', 'Team'],
  ];
  final skipped = <String>[];
  for (final MapEntry(key: tab, value: data) in tabs.entries) {
    final read = processSpreadsheetData(data);
    for (final runner in read.runners) {
      final ownTeam = (runner['team'] as String?)?.trim() ?? '';
      rows.add([
        runner['bib'] as String,
        runner['name'] as String,
        '${runner['grade']}',
        (runner['gender'] as String?) ?? '',
        ownTeam.isNotEmpty ? ownTeam : tab.trim(),
      ]);
    }
    for (final problem in read.skipped) {
      final lower = problem.isEmpty
          ? problem
          : problem[0].toLowerCase() + problem.substring(1);
      skipped.add('$tab, $lower');
    }
  }
  return CombinedTabs(rows, skipped);
}
