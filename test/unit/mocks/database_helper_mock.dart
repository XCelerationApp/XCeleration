import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'package:xceleration/utils/database_helper.dart';

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
        school: 'High School',
      ),
      RunnerRecord(
        runnerId: 2,
        raceId: raceId,
        bib: '102',
        name: 'Jane Smith',
        grade: 11,
        school: 'Another High School',
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
        school: 'High School',
      );
    }
    return null;
  }
}
