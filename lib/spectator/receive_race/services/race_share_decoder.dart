import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:xceleration/shared/models/database/race_result.dart';
import 'package:xceleration/shared/models/database/team.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/services/race_results_service.dart';
import 'package:xceleration/coach/race_results/model/team_record.dart';

class RaceShareDecodedData {
  final String title;
  final RaceResultsData results;
  RaceShareDecodedData({required this.title, required this.results});
}

class RaceShareDecoder {
  static RaceShareDecodedData decodeToResultsData(String jsonStr) {
    // Decode base64+gzip (V2 only)
    final Uint8List b = base64Decode(jsonStr);
    final String decoded = utf8.decode(gzip.decode(b));
    final Map<String, dynamic> map =
        jsonDecode(decoded) as Map<String, dynamic>;

    if (map['type'] != 'RACE_SHARE_V2') {
      throw Exception('Unsupported payload');
    }

    final raceMap = map['race'] as Map<String, dynamic>;
    final title = ((raceMap['name']?.toString() ?? 'Race').isNotEmpty
            ? raceMap['name'].toString()
            : 'Race') +
        ' Results';

    // Build RaceResult list from payload
    final List<RaceResult> results = [];
    final List teams = (map['teams'] as List?) ?? const [];
    final List rows = (map['r'] as List?) ?? const [];
    for (final row in rows) {
      if (row is List && row.length >= 4) {
        final int place = (row[0] as num?)?.toInt() ?? 0;
        final String name = row[1]?.toString() ?? '';
        final int? teamIndex = row[2] as int?;
        final int finishMs = (row[3] as num?)?.toInt() ?? 0;
        final String? teamLabel =
            (teamIndex != null && teamIndex >= 0 && teamIndex < teams.length)
                ? teams[teamIndex]?.toString()
                : null;
        results.add(RaceResult(
          place: place,
          runner: Runner(name: name, bibNumber: null, grade: null),
          team: teamLabel != null
              ? Team(name: teamLabel, abbreviation: teamLabel)
              : null,
          finishTime: finishMs > 0 ? Duration(milliseconds: finishMs) : null,
        ));
      }
    }

    // Compute team/individual aggregates using existing service helpers
    final individual = RaceResultsService.convertToResultsRecords(
        RaceResultsService.calculateIndividualResults(results));
    final teamResults = RaceResultsService.calculateTeamResults(results);
    RaceResultsService.sortAndPlaceTeams(teamResults);
    final h2h = teamResults.length >= 2 && teamResults.length <= 4
        ? RaceResultsService.calculateHeadToHeadResults(teamResults)
        : <List<TeamRecord>>[];

    return RaceShareDecodedData(
      title: title,
      results: RaceResultsData(
        resultsTitle: title,
        individualResults: individual,
        overallTeamResults: teamResults.map((r) => TeamRecord.from(r)).toList(),
        headToHeadTeamResults: h2h,
      ),
    );
  }
}
