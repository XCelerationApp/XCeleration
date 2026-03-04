import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import '../../shared/models/database/master_race.dart';
import 'dart:convert';
import 'dart:io';

/// Compresses and encodes a string using gzip+base64
String compressAndEncode(String input) {
  final bytes = utf8.encode(input);
  final compressed = gzip.encode(bytes);
  return base64Encode(compressed);
}

class RaceEncodeUtils {
  /// Encodes a race into a string format
  static Future<String> getEncodedRaceData(MasterRace masterRace) async {
    final race = await masterRace.race;
    final raceId = race.raceId!;
    final name = race.raceName!;
    final date = race.raceDate!;
    final raceRecord = RaceRecord(
      raceId: raceId,
      date: date,
      name: name,
      type: 'race', // Default type for race records
    );
    return raceRecord.encode();
  }
}

class BibEncodeUtils {
  /// Encodes a list of bib data into a string format
  static Future<String> getEncodedRunnersBibData(MasterRace masterRace) async {
    final raceParticipants = await masterRace.raceParticipants;
    Logger.d('Runners count: ${raceParticipants.length}');

    final bibData = await Future.wait(raceParticipants.map((runner) async {
      final raceRunner =
          await masterRace.getRaceRunnerFromRaceParticipant(runner);
      if (raceRunner == null) return '';
      return BibDatum.fromRaceRunner(raceRunner);
    }));

    return getEncodedBibData(bibData.cast<BibDatum>());
  }

  static Future<String> getEncodedBibData(List<BibDatum> bibData) async {
    // Build compact JSON: teams list + rows
    final Set<String> teamsSet = {};
    for (final b in bibData) {
      if (b.teamAbbreviation != null && b.teamAbbreviation!.isNotEmpty) {
        teamsSet.add(b.teamAbbreviation!);
      }
    }
    final List<String> teams = teamsSet.toList();
    final Map<String, int> teamIndex = {
      for (int i = 0; i < teams.length; i++) teams[i]: i
    };

    // Rows format: [bib, name, teamIndex, grade]
    final List<List<dynamic>> rows = [];
    for (final b in bibData) {
      final int? tIdx = (b.teamAbbreviation != null &&
              b.teamAbbreviation!.isNotEmpty &&
              teamIndex.containsKey(b.teamAbbreviation))
          ? teamIndex[b.teamAbbreviation]
          : null;
      rows.add([
        b.bib,
        b.name ?? '',
        tIdx,
        b.grade ?? '',
      ]);
    }

    final payload = <String, dynamic>{
      'teams': teams,
      'r': rows,
    };

    final json = jsonEncode(payload);
    return compressAndEncode(json);
  }
}

class TimingEncodeUtils {
  /// Encodes timing records into a string format
  static Future<String> encodeTimeRecords(List<TimingDatum> timingData) async {
    final encodedTimingData = timingData.map((timingDatum) {
      try {
        return timingDatum.encode();
      } catch (e) {
        Logger.e(
            '[TimingEncodeUtils.encodeTimeRecords] Failed to encode datum: $e');
        return '';
      }
    });
    final raw = encodedTimingData
        .where((encodedTimingDatum) => encodedTimingDatum.isNotEmpty)
        .join(',');
    return compressAndEncode(raw);
  }
}
