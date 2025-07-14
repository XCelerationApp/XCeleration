import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'package:xceleration/core/utils/database_helper.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {
  static final MockDatabaseHelper _instance = MockDatabaseHelper._internal();

  factory MockDatabaseHelper() {
    return _instance;
  }

  MockDatabaseHelper._internal();

  @override
  Future<List<RunnerRecord>> getRaceRunners(int raceId) async {
    return [
      RunnerRecord(
        runnerId: 1,
        raceId: raceId,
        bib: '101',
        name: 'John Doe',
        grade: 10,
        team: 'Team A',
        teamAbbreviation: 'TA',
      ),
      RunnerRecord(
        runnerId: 2,
        raceId: raceId,
        bib: '102',
        name: 'Jane Smith',
        grade: 11,
        team: 'Team B',
        teamAbbreviation: 'TB',
      ),
    ];
  }

  @override
  Future<RunnerRecord?> getRaceRunnerByBib(int raceId, String bib) async {
    if (bib == '101') {
      return RunnerRecord(
        runnerId: 1,
        raceId: raceId,
        bib: '101',
        name: 'John Doe',
        grade: 10,
        team: 'Team A',
        teamAbbreviation: 'TA',
      );
    } else if (bib == '102') {
      return RunnerRecord(
        runnerId: 2,
        raceId: raceId,
        bib: '102',
        name: 'Jane Smith',
        grade: 11,
        team: 'Team B',
        teamAbbreviation: 'TB',
      );
    }
    return null;
  }

  @override
  Future<List<RunnerRecord>> getRaceRunnersByBibs(
      int raceId, List<String> bibNumbers) async {
    List<RunnerRecord> results = [];
    for (String bib in bibNumbers) {
      // Only add non-null runners to the list
      final runner = await getRaceRunnerByBib(raceId, bib);
      if (runner != null) {
        results.add(runner);
      }
    }
    return results;
  }
}
