import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';

/// A race's runners as a spreadsheet, in the layout the import reads back:
/// Bib, Name, Grade, Team. A roster exported from one race, edited, and
/// imported into the next comes through unchanged.
class RosterExport {
  RosterExport._();

  static const headings = ['Bib', 'Name', 'Grade', 'Team'];

  /// The header row, then one row per runner, by team and then bib.
  static List<List<String>> rows(List<RaceRunner> runners) {
    final sorted = [...runners]..sort((a, b) {
        final byTeam = (a.team.name ?? '')
            .toLowerCase()
            .compareTo((b.team.name ?? '').toLowerCase());
        if (byTeam != 0) return byTeam;
        return _bibOrder(a.runner.bibNumber ?? '', b.runner.bibNumber ?? '');
      });
    return [
      headings,
      for (final r in sorted)
        [
          r.runner.bibNumber ?? '',
          r.runner.name ?? '',
          r.runner.grade?.toString() ?? '',
          r.team.name ?? '',
        ],
    ];
  }

  /// The CSV text of [rows].
  static String csv(List<RaceRunner> runners) =>
      const ListToCsvConverter().convert(rows(runners));

  /// Writes the roster to a CSV file named for the race.
  static Future<Result<XFile>> writeCsv(
      String raceName, List<RaceRunner> runners) async {
    try {
      final dir = await getTemporaryDirectory();
      final safe = raceName.trim().isEmpty
          ? 'Runners'
          : raceName.replaceAll(RegExp(r'[/\\:*?"<>|]'), '-');
      final file = File('${dir.path}/$safe runners.csv');
      await file.writeAsString(csv(runners));
      return Success(XFile(file.path, mimeType: 'text/csv'));
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not create the runners spreadsheet.',
        originalException: e,
      ));
    }
  }

  /// Numbers in number order ("9" before "10"), anything else as text.
  static int _bibOrder(String a, String b) {
    final x = int.tryParse(a);
    final y = int.tryParse(b);
    if (x != null && y != null && x != y) return x.compareTo(y);
    return a.compareTo(b);
  }
}
