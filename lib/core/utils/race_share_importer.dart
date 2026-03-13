import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/repositories/i_race_repository.dart';
import 'package:xceleration/core/repositories/i_results_repository.dart';
import 'package:xceleration/core/repositories/i_runner_repository.dart';
import 'package:xceleration/core/repositories/i_team_repository.dart';
import 'package:xceleration/shared/models/database/base_models.dart';
import 'package:xceleration/core/utils/logger.dart';

/// Imports a shared race payload into local DB (read-only tag via naming)
class RaceShareImporter {
  final IRunnerRepository _runners;
  final ITeamRepository _teams;
  final IRaceRepository _races;
  final IResultsRepository _results;

  RaceShareImporter({
    required IRunnerRepository runners,
    required ITeamRepository teams,
    required IRaceRepository races,
    required IResultsRepository results,
  })  : _runners = runners,
        _teams = teams,
        _races = races,
        _results = results;

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
      final raceId = await _races.createRace(race);

      // Teams (create if missing)
      final Map<String, int> teamKeyToId = {};
      for (final t in (map['teams'] as List?) ?? const []) {
        final tm = t as Map<String, dynamic>;
        final name = tm['name']?.toString() ?? '';
        if (name.isEmpty) continue;
        final existing = await _teams.getTeamByName(name);
        int teamId;
        if (existing != null) {
          teamId = existing.teamId!;
        } else {
          teamId = await _teams.createTeam(Team(
            name: name,
            abbreviation: tm['abbreviation']?.toString(),
            color: Color((tm['color'] as int?) ?? 0),
          ));
        }
        teamKeyToId[name] = teamId;
        await _races.addTeamParticipantToRace(
            TeamParticipant(raceId: raceId, teamId: teamId));
      }

      // Individual results → ensure runner + participant, then add result
      for (final r in (map['individual_results'] as List?) ?? const []) {
        final rm = r as Map<String, dynamic>;
        final name = rm['name']?.toString() ?? '';
        final bib = rm['bib_number']?.toString() ?? '';
        if (name.isEmpty || bib.isEmpty) continue;

        // Runner
        var runner = await _runners.getRunnerByBib(bib);
        if (runner == null) {
          final newId = await _runners.createRunner(Runner(
              name: name, bibNumber: bib, grade: rm['grade'] as int? ?? 0));
          runner = await _runners.getRunner(newId);
        }
        if (runner == null) continue;

        // Team association (optional)
        final teamName = rm['team_name']?.toString() ?? '';
        int? teamId;
        if (teamName.isNotEmpty) {
          teamId = teamKeyToId[teamName];
          if (teamId != null) {
            await _runners.addRunnerToTeam(teamId, runner.runnerId!);
          }
        }

        // Participant in this race
        await _races.addRaceParticipant(RaceParticipant(
          raceId: raceId,
          runnerId: runner.runnerId!,
          teamId: teamId ??
              (await _runners.getRunnerTeams(runner.runnerId!))
                  .firstOrNull
                  ?.teamId ??
              0,
        ));

        // Result
        final finishMs = rm['finish_time_ms'] as int?;
        final finish =
            finishMs != null ? Duration(milliseconds: finishMs) : null;
        await _results.addRaceResult(RaceResult(
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
