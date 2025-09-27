import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/database_helper.dart';
import 'package:xceleration/shared/models/database/base_models.dart';
import 'package:xceleration/core/utils/logger.dart';

/// Imports a shared race payload into local DB (read-only tag via naming)
class RaceShareImporter {
  static Future<void> importFromJson(
      BuildContext context, String jsonStr) async {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    if (map['type'] != 'RACE_SHARE_V1') {
      throw Exception('Unsupported payload');
    }

    final db = DatabaseHelper.instance;

    // Race
    final raceMap = map['race'] as Map<String, dynamic>;
    final raceName = (raceMap['name']?.toString() ?? 'Race') + ' (shared)';
    final race = Race(
      raceName: raceName,
      raceDate: raceMap['race_date'] != null
          ? DateTime.tryParse(raceMap['race_date'])
          : null,
      location: raceMap['location']?.toString() ?? '',
      distance: (raceMap['distance'] as num?)?.toDouble(),
      distanceUnit: raceMap['distance_unit']?.toString() ?? 'mi',
      flowState: Race.FLOW_FINISHED,
    );
    final raceId = await db.createRace(race);

    // Teams (create if missing)
    final Map<String, int> teamKeyToId = {};
    for (final t in (map['teams'] as List?) ?? const []) {
      final tm = t as Map<String, dynamic>;
      final name = tm['name']?.toString() ?? '';
      if (name.isEmpty) continue;
      final existing = await db.getTeamByName(name);
      int teamId;
      if (existing != null) {
        teamId = existing.teamId!;
      } else {
        final created = await db.createTeam(Team(
          name: name,
          abbreviation: tm['abbreviation']?.toString(),
          color: Color((tm['color'] as int?) ?? 0),
        ));
        teamId = created;
      }
      teamKeyToId[name] = teamId;
      await db.addTeamParticipantToRace(
          TeamParticipant(raceId: raceId, teamId: teamId));
    }

    // Individual results → ensure runner + participant, then add result
    for (final r in (map['individual_results'] as List?) ?? const []) {
      final rm = r as Map<String, dynamic>;
      final name = rm['name']?.toString() ?? '';
      final bib = rm['bib_number']?.toString() ?? '';
      if (name.isEmpty || bib.isEmpty) continue;

      // Runner
      var runner = await db.getRunnerByBib(bib);
      if (runner == null) {
        final newId = await db.createRunner(Runner(
            name: name, bibNumber: bib, grade: rm['grade'] as int? ?? 0));
        runner = await db.getRunner(newId);
      }
      if (runner == null) continue;

      // Team association (optional)
      final teamName = rm['team_name']?.toString() ?? '';
      int? teamId;
      if (teamName.isNotEmpty) {
        teamId = teamKeyToId[teamName];
        if (teamId != null) {
          await db.addRunnerToTeam(teamId, runner.runnerId!);
        }
      }

      // Participant in this race
      await db.addRaceParticipant(RaceParticipant(
        raceId: raceId,
        runnerId: runner.runnerId!,
        teamId: teamId ??
            (await db.getRunnerTeams(runner.runnerId!)).firstOrNull?.teamId ??
            0,
      ));

      // Result
      final finishMs = rm['finish_time_ms'] as int?;
      final finish = finishMs != null ? Duration(milliseconds: finishMs) : null;
      await db.addRaceResult(RaceResult(
        raceId: raceId,
        runner: runner,
        team: teamId != null ? Team(teamId: teamId, name: teamName) : null,
        place: rm['place'] as int?,
        finishTime: finish,
      ));
    }

    Logger.d('Imported shared race (id=$raceId)');
  }
}
