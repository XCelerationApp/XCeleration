import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/i_database_helper.dart';
import 'package:xceleration/shared/models/database/base_models.dart';
import 'package:xceleration/core/utils/logger.dart';

/// Imports a shared race payload into local DB (read-only tag via naming)
class RaceShareImporter {
  final IDatabaseHelper _db;

  RaceShareImporter({required IDatabaseHelper db}) : _db = db;

  Future<Result<void>> importFromJson(String jsonStr) async {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (map['type'] != 'RACE_SHARE_V1') {
        return Failure(AppError(
          userMessage:
              'Could not import race. The file format is not supported.',
          originalException:
              Exception('Unsupported payload type: ${map['type']}'),
        ));
      }

      // Race
      final raceMap = map['race'] as Map<String, dynamic>;
      final raceName = '${raceMap['name']?.toString() ?? 'Race'} (shared)';
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
      final raceId = await _db.createRace(race);

      // Teams (create if missing)
      final Map<String, int> teamKeyToId = {};
      for (final t in (map['teams'] as List?) ?? const []) {
        final tm = t as Map<String, dynamic>;
        final name = tm['name']?.toString() ?? '';
        if (name.isEmpty) continue;
        final existing = await _db.getTeamByName(name);
        int teamId;
        if (existing != null) {
          teamId = existing.teamId!;
        } else {
          final created = await _db.createTeam(Team(
            name: name,
            abbreviation: tm['abbreviation']?.toString(),
            color: Color((tm['color'] as int?) ?? 0),
          ));
          teamId = created;
        }
        teamKeyToId[name] = teamId;
        await _db.addTeamParticipantToRace(
            TeamParticipant(raceId: raceId, teamId: teamId));
      }

      // Individual results → ensure runner + participant, then add result
      for (final r in (map['individual_results'] as List?) ?? const []) {
        final rm = r as Map<String, dynamic>;
        final name = rm['name']?.toString() ?? '';
        final bib = rm['bib_number']?.toString() ?? '';
        if (name.isEmpty || bib.isEmpty) continue;

        // Runner
        var runner = await _db.getRunnerByBib(bib);
        if (runner == null) {
          final newId = await _db.createRunner(Runner(
              name: name, bibNumber: bib, grade: rm['grade'] as int? ?? 0));
          runner = await _db.getRunner(newId);
        }
        if (runner == null) continue;

        // Team association (optional)
        final teamName = rm['team_name']?.toString() ?? '';
        int? teamId;
        if (teamName.isNotEmpty) {
          teamId = teamKeyToId[teamName];
          if (teamId != null) {
            await _db.addRunnerToTeam(teamId, runner.runnerId!);
          }
        }

        // Participant in this race
        await _db.addRaceParticipant(RaceParticipant(
          raceId: raceId,
          runnerId: runner.runnerId!,
          teamId: teamId ??
              (await _db.getRunnerTeams(runner.runnerId!))
                  .firstOrNull
                  ?.teamId ??
              0,
        ));

        // Result
        final finishMs = rm['finish_time_ms'] as int?;
        final finish =
            finishMs != null ? Duration(milliseconds: finishMs) : null;
        await _db.addRaceResult(RaceResult(
          raceId: raceId,
          runner: runner,
          team: teamId != null ? Team(teamId: teamId, name: teamName) : null,
          place: rm['place'] as int?,
          finishTime: finish,
        ));
      }

      Logger.d('Imported shared race (id=$raceId)');
      return const Success(null);
    } catch (e) {
      Logger.e('[RaceShareImporter.importFromJson] $e');
      return Failure(AppError(
        userMessage: 'Could not import race. Please try again.',
        originalException: e,
      ));
    }
  }
}
