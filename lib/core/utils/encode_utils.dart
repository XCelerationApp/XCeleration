import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import '../../shared/models/database/master_race.dart';


class BibEncodeUtils {
  /// Encodes a list of runners for a race into a string format
  static Future<String> getEncodedRunnersBibData(MasterRace masterRace) async {
    final raceParticipants = await masterRace.raceParticipants;
    Logger.d('Runners count: ${raceParticipants.length}');

    // Parallelize the async operations using Future.wait
    final futures = raceParticipants.map((runner) async {
      final raceRunner =
          await masterRace.getRaceRunnerFromRaceParticipant(runner);
      if (raceRunner == null) return '';
      final bibDatum = BibDatum.fromRaceRunner(raceRunner);
      return bibDatum.encode();
    });

    final encodedBibData = await Future.wait(futures);
    return encodedBibData.where((encodedBibDatum) => encodedBibDatum.isNotEmpty).join(' ');
  }
}

class TimingEncodeUtils {
  /// Encodes timing records into a string format
  static Future<String> encodeTimeRecords(List<TimingDatum> timingData) async {
    // Parallelize the encoding operations
    final futures = timingData.map((timingDatum) async {
      try {
        return timingDatum.toEncodedString();
      } catch (e) {
        return '';
      }
    });

    final encodedTimingData = await Future.wait(futures);
    return encodedTimingData.where((encodedTimingDatum) => encodedTimingDatum.isNotEmpty).join(',');
  }
}
