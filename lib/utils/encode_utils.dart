import 'package:xceleration/core/utils/logger.dart';
import '../features/timing/models/timing_record.dart';
import '../coach/race_screen/widgets/runner_record.dart';
import '../utils/enums.dart';
import 'database_helper.dart';

/// Encodes a list of runners for a race into a string format
Future<String> getEncodedRunnersData(int raceId) async {
  final runners = await DatabaseHelper.instance.getRaceRunners(raceId);
  Logger.d('Runners count: ${runners.length}');
  return runners
      .map((runner) => [
            Uri.encodeComponent(runner.bib),
            Uri.encodeComponent(runner.name),
            Uri.encodeComponent(runner.school),
            Uri.encodeComponent(runner.grade.toString()),
          ].join(','))
      .join(' ');
}

/// Encodes timing records into a string format
String encodeTimeRecords(List<TimeRecord> records) {
  return records
      .map((record) {
        if (record.type == RecordType.runnerTime) {
          return record.elapsedTime;
        }

        // Handle conflict records with proper null checking
        if (record.conflict != null) {
          final data = record.conflict!.data;
          if (data != null &&
              data.containsKey('offBy') &&
              data['offBy'] != null) {
            return '${record.type} ${data['offBy']} ${record.elapsedTime}';
          }
        }

        return '';
      })
      .where((element) => element.isNotEmpty)
      .join(',');
}

/// Encodes bib records into a string format
String encodeBibRecords(List<RunnerRecord> runners) {
  return runners.map((runner) => runner.bib).join(',');
}
