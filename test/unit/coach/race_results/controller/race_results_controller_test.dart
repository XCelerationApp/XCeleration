// import 'package:flutter_test/flutter_test.dart';
// import 'package:xceleration/coach/race_results/controller/race_results_controller.dart';
// import 'package:mockito/mockito.dart';
// import 'package:xceleration/core/utils/database_helper.dart';
// import 'package:xceleration/coach/race_results/model/results_record.dart';

// // Manual mock class
// class MockDatabaseHelper extends Mock implements DatabaseHelper {
//   @override
//   Future<List<ResultsRecord>> getRaceResults(int raceId) async {
//     if (raceId == 1) {
//       return [
//         ResultsRecord(
//           place: 0,
//           name: 'Runner B',
//           team: 'Team B',
//           teamAbbreviation: 'TB',
//           finishTime: Duration(minutes: 20),
//           grade: 12,
//           bib: '102',
//           raceId: raceId,
//           runnerId: 102,
//         ),
//         ResultsRecord(
//           place: 0,
//           name: 'Runner A',
//           team: 'Team A',
//           teamAbbreviation: 'TA',
//           finishTime: Duration(minutes: 16, seconds: 40),
//           grade: 11,
//           bib: '101',
//           raceId: raceId,
//           runnerId: 101,
//         ),
//       ];
//     } else if (raceId == 2) {
//       return [];
//     } else {
//       return [];
//     }
//   }
// }

// void main() {
//   group('RaceResultsController Empty Tests', () {
//     late MockDatabaseHelper mockDbHelper;
//     late RaceResultsController controller;

//     setUp(() async {
//       mockDbHelper = MockDatabaseHelper();

//       // Initialize controller with mock
//       controller = RaceResultsController(raceId: 0, dbHelper: mockDbHelper);

//       // Wait for the async initialization to complete
//       while (controller.isLoading) {
//         await Future.delayed(Duration(milliseconds: 10));
//       }
//     });

//     test('should initialize with empty results', () {
//       expect(controller.individualResults, isEmpty);
//       expect(controller.overallTeamResults, isEmpty);
//       expect(controller.headToHeadTeamResults, isNull);
//     });
//   });

//   group('RaceResultsController Tests', () {
//     late MockDatabaseHelper mockDbHelper;
//     late RaceResultsController controller;

//     setUp(() async {
//       mockDbHelper = MockDatabaseHelper();

//       // Initialize controller with mock
//       controller = RaceResultsController(raceId: 1, dbHelper: mockDbHelper);

//       // Wait for the async initialization to complete
//       while (controller.isLoading) {
//         await Future.delayed(Duration(milliseconds: 10));
//       }
//     });

//     test('should properly sort runners by finish time', () async {
//       // Verify results were sorted by finish time
//       expect(controller.individualResults.length, 2);
//       expect(controller.individualResults[0].name,
//           'Runner A'); // Faster runner first
//       expect(controller.individualResults[0].place, 1); // Should be place 1
//       expect(controller.individualResults[1].name, 'Runner B');
//       expect(controller.individualResults[1].place, 2); // Should be place 2
//     });

//     test('should handle teams with no scorers', () {
//       expect(controller.individualResults.length, 2);
//       expect(controller.overallTeamResults.length, 2);
//       expect(controller.overallTeamResults[0].score, 0);
//       expect(controller.overallTeamResults[1].score, 0);
//       expect(controller.overallTeamResults[0].avgTime, Duration.zero);
//       expect(controller.overallTeamResults[1].split, Duration.zero);
//       expect(controller.headToHeadTeamResults, isNull);
//     });
//   });
// }
void main() {}
