// import '../../../shared/models/time_record.dart';
// import '../../../core/utils/enums.dart';
// import '../../race_screen/widgets/runner_record.dart';
// import '../model/timing_data.dart';

// /// Mock data generator for testing conflict resolution functionality
// /// Creates realistic race scenarios with various types of conflicts
// class MockDataGenerator {
//   /// Generates a complete race scenario with runners and timing data
//   static MockRaceData generateRaceScenario({
//     MockScenarioType scenario = MockScenarioType.mixed,
//     int runnerCount = 10,
//   }) {
//     switch (scenario) {
//       case MockScenarioType.missingTimes:
//         return _generateMissingTimesScenario(runnerCount);
//       case MockScenarioType.extraTimes:
//         return _generateExtraTimesScenario(runnerCount);
//       case MockScenarioType.mixed:
//         return _generateMixedConflictsScenario(runnerCount);
//       case MockScenarioType.clean:
//         return _generateCleanRaceScenario(runnerCount);
//       case MockScenarioType.complex:
//         return _generateComplexScenario(runnerCount);
//     }
//   }

//   /// Generates scenario with missing time conflicts
//   static MockRaceData _generateMissingTimesScenario(int runnerCount) {
//     final runners = _generateRunners(runnerCount);
//     final records = <TimeRecord>[];

//     // Add normal times for first few runners
//     for (int i = 1; i <= 2; i++) {
//       records.add(TimeRecord(
//         elapsedTime: '$i.${(i * 15).toString().padLeft(2, '0')}',
//         type: RecordType.runnerTime,
//         place: i,
//         isConfirmed: true,
//       ));
//     }

//     // Add confirmRunner record after place 2
//     records.add(TimeRecord(
//       elapsedTime: '2.30',
//       type: RecordType.confirmRunner,
//       place: 2,
//       isConfirmed: true,
//     ));

//     // Add missing time conflict at place 3
//     // First the TBD runner time record
//     records.add(TimeRecord(
//       elapsedTime: 'TBD',
//       type: RecordType.runnerTime,
//       place: 3,
//       isConfirmed: false,
//       conflict: ConflictDetails(
//         type: RecordType.missingTime,
//         data: {'offBy': 1, 'numTimes': runnerCount},
//       ),
//     ));

//     // Then the missingTime conflict record
//     records.add(TimeRecord(
//       elapsedTime: '3.25',
//       type: RecordType.missingTime,
//       place: 3,
//       conflict: ConflictDetails(
//         type: RecordType.missingTime,
//         data: {'offBy': 1, 'numTimes': runnerCount},
//       ),
//     ));

//     // Add remaining normal times
//     for (int i = 4; i <= runnerCount; i++) {
//       records.add(TimeRecord(
//         elapsedTime: '$i.${(i * 12).toString().padLeft(2, '0')}',
//         type: RecordType.runnerTime,
//         place: i,
//         isConfirmed: true,
//       ));
//     }

//     return MockRaceData(
//       runners: runners,
//       timingData:
//           TimingData(records: records, endTime: '${runnerCount + 2}.00'),
//       scenarioName: 'Missing Times Scenario',
//       description: 'Runner at place 3 has missing time (TBD)',
//     );
//   }

//   /// Generates scenario with extra time conflicts
//   static MockRaceData _generateExtraTimesScenario(int runnerCount) {
//     final runners = _generateRunners(runnerCount);
//     final records = <TimeRecord>[];

//     // Add normal times for first couple runners
//     for (int i = 1; i <= 2; i++) {
//       records.add(TimeRecord(
//         elapsedTime: '$i.${(i * 18).toString().padLeft(2, '0')}',
//         type: RecordType.runnerTime,
//         place: i,
//         isConfirmed: true,
//       ));
//     }

//     // Add confirmRunner after place 2
//     records.add(TimeRecord(
//       elapsedTime: '2.30',
//       type: RecordType.confirmRunner,
//       place: 2,
//       isConfirmed: true,
//     ));

//     // Add runner time records that will have extra times
//     for (int i = 3; i <= 4; i++) {
//       records.add(TimeRecord(
//         elapsedTime: '$i.${(i * 15).toString().padLeft(2, '0')}',
//         type: RecordType.runnerTime,
//         place: i == 4 ? null : i, // Extra runner gets place: null
//         isConfirmed: false, // Not confirmed because of extra time conflict
//         conflict: ConflictDetails(
//           type: RecordType.extraTime,
//           data: {'offBy': 1, 'numTimes': runnerCount + 1},
//         ),
//       ));
//     }

//     // Add the extra time record at place 4
//     records.add(TimeRecord(
//       elapsedTime: '4.25',
//       type: RecordType.extraTime,
//       place: null, // Extra time record - no corresponding runner place
//       conflict: ConflictDetails(
//         type: RecordType.extraTime,
//         data: {'offBy': 1, 'numTimes': runnerCount + 1},
//       ),
//     ));

//     // Add remaining normal times
//     for (int i = 5; i <= runnerCount; i++) {
//       records.add(TimeRecord(
//         elapsedTime: '$i.${(i * 12).toString().padLeft(2, '0')}',
//         type: RecordType.runnerTime,
//         place: i,
//         isConfirmed: true,
//       ));
//     }

//     return MockRaceData(
//       runners: runners,
//       timingData:
//           TimingData(records: records, endTime: '${runnerCount + 1}.00'),
//       scenarioName: 'Extra Times Scenario',
//       description: 'Extra time recorded at place 4 needs to be removed',
//     );
//   }

//   /// Generates scenario with mixed conflicts
//   static MockRaceData _generateMixedConflictsScenario(int runnerCount) {
//     final runners = _generateRunners(runnerCount);
//     final records = <TimeRecord>[];

//     // Normal times for places 1-2
//     for (int i = 1; i <= 2; i++) {
//       records.add(TimeRecord(
//         elapsedTime: '$i.${(i * 20).toString().padLeft(2, '0')}',
//         type: RecordType.runnerTime,
//         place: i,
//         isConfirmed: true,
//       ));
//     }

//     // ConfirmRunner after place 2
//     records.add(TimeRecord(
//       elapsedTime: '2.30',
//       type: RecordType.confirmRunner,
//       place: 2,
//       isConfirmed: true,
//     ));

//     // Missing time conflict at place 3
//     records.add(TimeRecord(
//       elapsedTime: 'TBD',
//       type: RecordType.runnerTime,
//       place: 3,
//       isConfirmed: false,
//       conflict: ConflictDetails(
//         type: RecordType.missingTime,
//         data: {'offBy': 1, 'numTimes': runnerCount},
//       ),
//     ));

//     records.add(TimeRecord(
//       elapsedTime: '3.15',
//       type: RecordType.missingTime,
//       place: 3,
//       conflict: ConflictDetails(
//         type: RecordType.missingTime,
//         data: {'offBy': 1, 'numTimes': runnerCount},
//       ),
//     ));

//     // Normal time at place 4
//     records.add(TimeRecord(
//       elapsedTime: '4.10',
//       type: RecordType.runnerTime,
//       place: 4,
//       isConfirmed: true,
//     ));

//     // Normal time at place 5
//     records.add(TimeRecord(
//       elapsedTime: '5.75',
//       type: RecordType.runnerTime,
//       place: 5,
//       isConfirmed: true,
//     ));

//     // Extra time conflict at places 5-6 (extra runner gets place: null)
//     records.add(TimeRecord(
//       elapsedTime: '6.05',
//       type: RecordType.runnerTime,
//       place: null,
//       isConfirmed: false,
//       conflict: ConflictDetails(
//         type: RecordType.extraTime,
//         data: {'offBy': 1, 'numTimes': runnerCount + 1},
//       ),
//     ));

//     // Add the extra time record
//     records.add(TimeRecord(
//       elapsedTime: '6.25',
//       type: RecordType.extraTime,
//       place: null, // Extra time record - no corresponding runner place
//       conflict: ConflictDetails(
//         type: RecordType.extraTime,
//         data: {'offBy': 1, 'numTimes': runnerCount + 1},
//       ),
//     ));

//     // Normal time at place 6
//     records.add(TimeRecord(
//       elapsedTime: '6.48',
//       type: RecordType.runnerTime,
//       place: 6,
//       isConfirmed: true,
//     ));

//     // Remaining normal times
//     for (int i = 7; i <= runnerCount; i++) {
//       records.add(TimeRecord(
//         elapsedTime: '$i.${(i * 8).toString().padLeft(2, '0')}',
//         type: RecordType.runnerTime,
//         place: i,
//         isConfirmed: true,
//       ));
//     }

//     return MockRaceData(
//       runners: runners,
//       timingData:
//           TimingData(records: records, endTime: '${runnerCount + 1}.00'),
//       scenarioName: 'Mixed Conflicts Scenario',
//       description: 'Missing time at place 3, extra time at place 6',
//     );
//   }

//   /// Generates clean race scenario (no conflicts)
//   static MockRaceData _generateCleanRaceScenario(int runnerCount) {
//     final runners = _generateRunners(runnerCount);
//     final records = <TimeRecord>[];

//     for (int i = 1; i <= runnerCount; i++) {
//       records.add(TimeRecord(
//         elapsedTime: '$i.${(i * 15).toString().padLeft(2, '0')}',
//         type: RecordType.runnerTime,
//         place: i,
//         isConfirmed: true,
//       ));
//     }

//     return MockRaceData(
//       runners: runners,
//       timingData:
//           TimingData(records: records, endTime: '${runnerCount + 1}.00'),
//       scenarioName: 'Clean Race Scenario',
//       description: 'Perfect race with no conflicts',
//     );
//   }

//   /// Generates complex scenario with multiple conflicts
//   static MockRaceData _generateComplexScenario(int runnerCount) {
//     final runners = _generateRunners(runnerCount);
//     final records = <TimeRecord>[];

//     // Place 1: Normal
//     records.add(TimeRecord(
//       elapsedTime: '1.25',
//       type: RecordType.runnerTime,
//       place: 1,
//       isConfirmed: true,
//     ));

//     // ConfirmRunner after place 1
//     records.add(TimeRecord(
//       elapsedTime: '1.30',
//       type: RecordType.confirmRunner,
//       place: 1,
//       isConfirmed: true,
//     ));

//     // Places 2-3: Missing times (offBy = 2)
//     records.add(TimeRecord(
//       elapsedTime: 'TBD',
//       type: RecordType.runnerTime,
//       place: 2,
//       isConfirmed: false,
//       conflict: ConflictDetails(
//         type: RecordType.missingTime,
//         data: {'offBy': 2, 'numTimes': 3},
//       ),
//     ));

//     records.add(TimeRecord(
//       elapsedTime: 'TBD',
//       type: RecordType.runnerTime,
//       place: 3,
//       isConfirmed: false,
//       conflict: ConflictDetails(
//         type: RecordType.missingTime,
//         data: {'offBy': 2, 'numTimes': 3},
//       ),
//     ));

//     // Missing time conflict records
//     records.add(TimeRecord(
//       elapsedTime: '3.15',
//       type: RecordType.missingTime,
//       place: 3,
//       conflict: ConflictDetails(
//         type: RecordType.missingTime,
//         data: {'offBy': 2, 'numTimes': 3},
//       ),
//     ));

//     // Places 4-5: Normal
//     for (int i = 4; i <= 5; i++) {
//       records.add(TimeRecord(
//         elapsedTime: '$i.${(i * 10).toString().padLeft(2, '0')}',
//         type: RecordType.runnerTime,
//         place: i,
//         isConfirmed: true,
//       ));
//     }

//     // Place 6: Extra times (offBy = 2)
//     records.add(TimeRecord(
//       elapsedTime: '6.15',
//       type: RecordType.runnerTime,
//       place: 6,
//       isConfirmed: false,
//       conflict: ConflictDetails(
//         type: RecordType.extraTime,
//         data: {'offBy': 2, 'numTimes': 6},
//       ),
//     ));

//     // Extra runner records (place: null since they're extra)
//     records.add(TimeRecord(
//       elapsedTime: '6.22',
//       type: RecordType.runnerTime,
//       place: null,
//       isConfirmed: false,
//       conflict: ConflictDetails(
//         type: RecordType.extraTime,
//         data: {'offBy': 2, 'numTimes': 6},
//       ),
//     ));

//     records.add(TimeRecord(
//       elapsedTime: '6.28',
//       type: RecordType.runnerTime,
//       place: null,
//       isConfirmed: false,
//       conflict: ConflictDetails(
//         type: RecordType.extraTime,
//         data: {'offBy': 2, 'numTimes': 6},
//       ),
//     ));

//     // Extra time conflict records
//     records.add(TimeRecord(
//       elapsedTime: '6.35',
//       type: RecordType.extraTime,
//       place: null, // Extra time record - no corresponding runner place
//       conflict: ConflictDetails(
//         type: RecordType.extraTime,
//         data: {'offBy': 2, 'numTimes': 6},
//       ),
//     ));

//     // Remaining places: Normal
//     for (int i = 7; i <= runnerCount; i++) {
//       records.add(TimeRecord(
//         elapsedTime: '$i.${(i * 8).toString().padLeft(2, '0')}',
//         type: RecordType.runnerTime,
//         place: i,
//         isConfirmed: true,
//       ));
//     }

//     return MockRaceData(
//       runners: runners,
//       timingData:
//           TimingData(records: records, endTime: '${runnerCount + 2}.00'),
//       scenarioName: 'Complex Scenario',
//       description:
//           'Multiple missing times (places 2-3) and extra times (place 6)',
//     );
//   }

//   /// Generates realistic runner records
//   static List<RunnerRecord> _generateRunners(int count) {
//     final teams = [
//       'Lincoln High',
//       'Washington Middle',
//       'Roosevelt Elementary',
//       'Jefferson Academy',
//       'Madison Prep'
//     ];
//     final teamAbbreviations = ['LH', 'WM', 'RE', 'JA', 'MP'];
//     final firstNames = [
//       'Alex',
//       'Jordan',
//       'Casey',
//       'Taylor',
//       'Morgan',
//       'Riley',
//       'Avery',
//       'Quinn',
//       'Sage',
//       'River'
//     ];
//     final lastNames = [
//       'Smith',
//       'Johnson',
//       'Williams',
//       'Brown',
//       'Jones',
//       'Garcia',
//       'Miller',
//       'Davis',
//       'Rodriguez',
//       'Martinez'
//     ];

//     return List.generate(count, (index) {
//       final bibNumber = (index + 1).toString().padLeft(3, '0');
//       final firstName = firstNames[index % firstNames.length];
//       final lastName = lastNames[index % lastNames.length];
//       final team = teams[index % teams.length];
//       final teamAbbreviation =
//           teamAbbreviations[index % teamAbbreviations.length];
//       final grade = 9 + (index % 4); // Grades 9-12

//       return RunnerRecord(
//         runnerId: index + 1,
//         raceId: 1,
//         bib: bibNumber,
//         name: '$firstName $lastName',
//         team: team,
//         teamAbbreviation: teamAbbreviation,
//         grade: grade,
//       );
//     });
//   }

//   /// Generates preset scenarios for quick testing
//   static List<MockRaceData> getPresetScenarios() {
//     return [
//       generateRaceScenario(scenario: MockScenarioType.clean, runnerCount: 8),
//       generateRaceScenario(
//           scenario: MockScenarioType.missingTimes, runnerCount: 8),
//       generateRaceScenario(
//           scenario: MockScenarioType.extraTimes, runnerCount: 8),
//       generateRaceScenario(scenario: MockScenarioType.mixed, runnerCount: 10),
//       generateRaceScenario(scenario: MockScenarioType.complex, runnerCount: 12),
//     ];
//   }
// }

// /// Types of conflict scenarios to generate
// enum MockScenarioType {
//   clean, // No conflicts
//   missingTimes, // Missing time conflicts
//   extraTimes, // Extra time conflicts
//   mixed, // Mix of different conflicts
//   complex, // Complex scenario with multiple conflicts
// }

// /// Container for mock race data
// class MockRaceData {
//   final List<RunnerRecord> runners;
//   final TimingData timingData;
//   final String scenarioName;
//   final String description;

//   MockRaceData({
//     required this.runners,
//     required this.timingData,
//     required this.scenarioName,
//     required this.description,
//   });

//   /// Summary of conflicts in this scenario
//   String get conflictSummary {
//     final conflicts =
//         timingData.records.where((r) => r.conflict != null).length;
//     if (conflicts == 0) return 'No conflicts';
//     return '$conflicts conflict records';
//   }

//   @override
//   String toString() {
//     return '$scenarioName: ${runners.length} runners, ${timingData.records.length} records, $conflictSummary';
//   }
// }
