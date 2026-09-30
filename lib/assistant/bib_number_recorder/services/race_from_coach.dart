import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/models/runner.dart' as db_models;
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/assistant/shared/services/received_race_resolver.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';

/// A race the coach sent the Bib Recorder, as stored on this phone.
class StoredRaceFromCoach {
  const StoredRaceFromCoach({required this.race, required this.runners});

  /// The race to open, under the number this phone keeps it by.
  final RaceRecord race;

  /// The roster sent with it; empty when none was.
  final List<BibDatum> runners;
}

/// Reads the race and roster the coach sends the Bib Recorder
/// ("race---roster"), stores them on this phone and says which race to open.
///
/// Used for a race received from another phone, and for one handed over by
/// the coach on this same phone. A race already here with bibs recorded, or
/// one sharing its number under another name, is settled by [ask]: see
/// [resolveReceivedRace].
Future<Result<StoredRaceFromCoach>> storeRaceFromCoach(
  IAssistantStorageService storage,
  String data, {
  AskAboutRace? ask,
}) async {
  final RaceRecord sent;
  var runners = <BibDatum>[];
  try {
    final parts = data.split('---');
    sent = RaceRecord.fromEncodedString(parts[0],
        type: DeviceName.bibRecorder.toString());
    if (parts.length == 2) {
      switch (await BibDecodeUtils.decodeEncodedRunners(parts[1])) {
        case Success(:final value):
          runners = value;
        case Failure(:final error):
          Logger.e('[storeRaceFromCoach] ${error.originalException}');
          return Failure(error);
      }
    }
  } catch (e) {
    Logger.e('Error parsing race data: $e');
    return Failure(AppError(userMessage: 'Failed to parse race data: $e'));
  }

  // The coach may send the same race again, for instance with runners added
  // since: that opens the race already here, bibs and all, unless the
  // volunteer asks for a copy.
  final RaceRecord race;
  switch (await resolveReceivedRace(
    storage: storage,
    sent: sent,
    countRecorded: (existing) async =>
        switch (await storage.getBibRecords(existing.raceId)) {
      Success(:final value) => value.where((r) => r.bibNumber.isNotEmpty).length,
      Failure() => 0,
    },
    rosterChanges: runners.isEmpty
        ? null
        : (existing) => _rosterChanges(storage, existing, runners),
    ask: ask,
  )) {
    case Success(:final value):
      race = value.race;
    case Failure(:final error):
      Logger.e('[storeRaceFromCoach] ${error.originalException}');
      return Failure(error);
  }

  if (runners.isNotEmpty) {
    await storage.saveRunners(race.raceId, [
      for (final runner in runners)
        db_models.Runner(
          raceId: race.raceId,
          bibNumber: runner.bib,
          name: runner.name,
          teamAbbreviation: runner.teamAbbreviation,
          grade: runner.grade,
          teamColor: runner.teamColor,
          createdAt: DateTime.now(),
        ),
    ]);
  }
  return Success(StoredRaceFromCoach(race: race, runners: runners));
}

Future<RosterChanges?> _rosterChanges(IAssistantStorageService storage,
    RaceRecord race, List<BibDatum> sent) async {
  switch (await storage.getRunners(race.raceId)) {
    case Failure():
      return null;
    case Success(:final value):
      return RosterChanges.between([
        for (final r in value)
          BibDatum(
            bib: r.bibNumber,
            name: r.name,
            teamAbbreviation: r.teamAbbreviation,
            grade: r.grade,
          ),
      ], sent);
  }
}

/// A race the coach on this phone has just handed to its Bib Recorder, to
/// open when the Bib Recorder is next opened. Only for this session: the
/// coach switches roles straight away.
abstract final class RaceHandedOver {
  static int? bibRecorderRaceId;
}
