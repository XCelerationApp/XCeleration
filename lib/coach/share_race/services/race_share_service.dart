import 'dart:convert';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race.dart';
import 'package:xceleration/shared/models/database/race_result.dart';
import 'package:xceleration/shared/models/database/team.dart';
import 'package:xceleration/core/utils/logger.dart';

/// Builds the spectator payload for wireless sharing
class RaceShareService {
  /// Prepare a compact JSON string payload for spectators.
  /// For now, include race metadata and computed results summary.
  static Future<String> prepareSpectatorPayload(MasterRace masterRace) async {
    final race = await masterRace.race;
    if (race.flowState != Race.FLOW_FINISHED) {
      throw Exception('Race must be finished to share wirelessly');
    }

    try {
      // Minimal payload v1: race headers + raw result rows
      final List<RaceResult> results = await masterRace.results;

      final payload = {
        'type': 'RACE_SHARE_V1',
        'race': {
          'uuid': race.uuid,
          'name': race.raceName,
          'race_date': race.raceDate?.toIso8601String(),
          'location': race.location,
          'distance': race.distance,
          'distance_unit': race.distanceUnit,
          'flow_state': race.flowState,
        },
        'individual_results': results
            .map((r) => {
                  'place': r.place,
                  'name': r.runner?.name,
                  'team_abbreviation': r.team?.abbreviation,
                  'team_name': r.team?.name,
                  'team_color': r.team?.color?.toARGB32(),
                  'finish_time_ms': r.finishTime?.inMilliseconds,
                  'bib_number': r.runner?.bibNumber,
                  'grade': r.runner?.grade,
                })
            .toList(),
        'teams': _collectTeams(results)
            .map((t) => {
                  'name': t.name,
                  'abbreviation': t.abbreviation,
                  'color': t.color?.toARGB32(),
                })
            .toList(),
      };

      return jsonEncode(payload);
    } catch (e) {
      Logger.e('Error building spectator payload: $e');
      rethrow;
    }
  }

  static List<Team> _collectTeams(List<RaceResult> results) {
    final Map<String, Team> byAbbrev = {};
    for (final r in results) {
      final t = r.team;
      if (t == null) continue;
      final key = (t.abbreviation ?? t.name ?? '').toLowerCase();
      if (key.isEmpty) continue;
      byAbbrev[key] = t;
    }
    return byAbbrev.values.toList();
  }
}
