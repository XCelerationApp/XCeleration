import 'dart:convert';
import 'dart:io';
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
      final List<RaceResult> results = await masterRace.results;
      return preparePayloadFromData(race: race, results: results);
    } catch (e) {
      Logger.e('Error building spectator payload: $e');
      rethrow;
    }
  }

  /// Helper used by tests and by [prepareSpectatorPayload] to build payloads
  static String preparePayloadFromData({
    required Race race,
    required List<RaceResult> results,
  }) {
    // Build compact teams list (use abbreviation, fallback to name)
    final teams = _collectTeams(results);
    final teamList = teams
        .map((t) => (t.abbreviation ?? t.name ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
    final Map<String, int> teamIndex = {
      for (int i = 0; i < teamList.length; i++) teamList[i]: i
    };

    // Results rows compact format: [place, name, teamId, finish_ms]
    final rows = <List<dynamic>>[];
    for (final r in results) {
      final abbr = (r.team?.abbreviation ?? r.team?.name ?? '').toString();
      final tId = teamIndex[abbr] ?? -1;
      rows.add([
        r.place ?? 0,
        r.runner?.name ?? '',
        tId < 0 ? null : tId,
        r.finishTime?.inMilliseconds ?? 0,
      ]);
    }

    final payload = {
      'type': 'RACE_SHARE_V2',
      'race': {
        'uuid': race.uuid,
        'name': race.raceName,
        'race_date': race.raceDate?.toIso8601String(),
        'location': race.location,
        'distance': race.distance,
        'distance_unit': race.distanceUnit,
        'flow_state': race.flowState,
      },
      // Teams encoded by abbreviation; rows reference by index
      'teams': teamList,
      // Compact rows array
      'r': rows,
    };

    final json = jsonEncode(payload);
    // gzip + base64 for transport
    final bytes = gzip.encode(utf8.encode(json));
    return base64Encode(bytes);
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
