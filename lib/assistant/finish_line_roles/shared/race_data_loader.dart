import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';

/// Parses race data received from the Coach, saves the race and runners to
/// [storage], then calls [onComplete]. Returns [Failure] with a user-readable
/// message if parsing or saving fails.
///
/// Shared across finish-line role controllers (BibRecorderV2, Verifier, Fixer).
Future<Result<void>> processLoadedRaceDataShared({
  required String data,
  required DeviceName deviceName,
  required IAssistantStorageService storage,
  required Future<void> Function() onComplete,
}) async {
  final tag = deviceName.toString();
  late RaceRecord raceRecord;
  List<BibDatum> loadedRunners = [];

  try {
    final parts = data.split('---');
    if (parts.length == 2) {
      raceRecord = RaceRecord.fromEncodedString(parts[0], type: tag);

      final runnersResult =
          await BibDecodeUtils.decodeEncodedRunners(parts[1]);
      switch (runnersResult) {
        case Success(:final value):
          loadedRunners = value;
        case Failure(:final error):
          Logger.e('[$tag.processLoadedRaceData] ${error.originalException}');
          return Failure(error);
      }
    } else {
      raceRecord = RaceRecord.fromEncodedString(data, type: tag);
    }
  } catch (e) {
    Logger.e('Error parsing race data: $e');
    return Failure(AppError(userMessage: 'Failed to parse race data: $e'));
  }

  final saveResult = await storage.saveNewRace(raceRecord);
  if (saveResult case Failure(:final error)) {
    Logger.e('[$tag.processLoadedRaceData] ${error.originalException}');
    await onComplete();
    return Failure(error);
  }

  if (loadedRunners.isNotEmpty) {
    final dbRunners = loadedRunners
        .map((runner) => Runner(
              raceId: raceRecord.raceId,
              bibNumber: runner.bib,
              name: runner.name,
              teamAbbreviation: runner.teamAbbreviation,
              grade: runner.grade,
              teamColor: runner.teamColor,
              createdAt: DateTime.now(),
            ))
        .toList();
    await storage.saveRunners(raceRecord.raceId, dbRunners);
  }

  await onComplete();
  return const Success(null);
}
