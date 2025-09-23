import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import '../../shared/models/database/master_race.dart';

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
    return bibData.map((bibDatum) => bibDatum.encode()).join(' ');
  }
}

class TimingEncodeUtils {
  /// Encodes timing records into a string format
  static Future<String> encodeTimeRecords(List<TimingDatum> timingData) async {
    final encodedTimingData = timingData.map((timingDatum) {
      try {
        return timingDatum.encode();
      } catch (e) {
        return '';
      }
    });
    return encodedTimingData.where((encodedTimingDatum) => encodedTimingDatum.isNotEmpty).join(',');
  }
}
