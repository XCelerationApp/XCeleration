import 'dart:convert';
import 'package:flutter/material.dart';
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
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    if (map['type'] != 'RACE_SHARE_V1') {
      throw Exception('Unsupported payload');
    }

    final raceMap = map['race'] as Map<String, dynamic>;
    final title = ((raceMap['name']?.toString() ?? 'Race').isNotEmpty
            ? raceMap['name'].toString()
            : 'Race') +
        ' Results';

    // Build RaceResult list from payload
    final List<RaceResult> results = [];
    for (final r in (map['individual_results'] as List?) ?? const []) {
      final rm = r as Map<String, dynamic>;
      final finishMs = rm['finish_time_ms'] as int?;
      final teamName = rm['team_name']?.toString();
      final teamAbbrev = rm['team_abbreviation']?.toString();
      final teamColor =
          rm['team_color'] is int ? Color(rm['team_color'] as int) : null;
      results.add(RaceResult(
        place: rm['place'] as int?,
        runner: Runner(
          name: rm['name']?.toString(),
          bibNumber: rm['bib_number']?.toString(),
          grade: rm['grade'] as int?,
        ),
        team: (teamName != null || teamAbbrev != null)
            ? Team(name: teamName, abbreviation: teamAbbrev, color: teamColor)
            : null,
        finishTime: finishMs != null ? Duration(milliseconds: finishMs) : null,
      ));
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
