import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/merge_conflicts/demo/mock_data_generator.dart';
import 'package:xceleration/core/utils/enums.dart';

void main() {
  group('MockDataGenerator', () {
    test('generates clean race scenario without conflicts', () {
      final mockData = MockDataGenerator.generateRaceScenario(
        scenario: MockScenarioType.clean,
        runnerCount: 5,
      );

      expect(mockData.runners.length, equals(5));
      expect(mockData.timingData.records.length, equals(5));
      expect(mockData.scenarioName, equals('Clean Race Scenario'));

      // Verify no conflicts
      final conflictRecords =
          mockData.timingData.records.where((r) => r.conflict != null).toList();
      expect(conflictRecords.length, equals(0));

      // Verify all records are confirmed
      final confirmedRecords =
          mockData.timingData.records.where((r) => r.isConfirmed).toList();
      expect(confirmedRecords.length, equals(5));
    });

    test('generates missing times scenario with conflicts', () {
      final mockData = MockDataGenerator.generateRaceScenario(
        scenario: MockScenarioType.missingTimes,
        runnerCount: 8,
      );

      expect(mockData.runners.length, equals(8));
      expect(mockData.scenarioName, equals('Missing Times Scenario'));

      // Should have conflict records
      final conflictRecords =
          mockData.timingData.records.where((r) => r.conflict != null).toList();
      expect(conflictRecords.length, greaterThan(0));

      // Should have a TBD record
      final tbdRecords = mockData.timingData.records
          .where((r) => r.elapsedTime == 'TBD')
          .toList();
      expect(tbdRecords.length, equals(1));

      // Should have missing time type records
      final missingTimeRecords = mockData.timingData.records
          .where((r) => r.type == RecordType.missingTime)
          .toList();
      expect(missingTimeRecords.length, equals(1));
    });

    test('generates extra times scenario with conflicts', () {
      final mockData = MockDataGenerator.generateRaceScenario(
        scenario: MockScenarioType.extraTimes,
        runnerCount: 6,
      );

      expect(mockData.runners.length, equals(6));
      expect(mockData.scenarioName, equals('Extra Times Scenario'));

      // Should have more records than runners due to extra time
      expect(mockData.timingData.records.length, greaterThan(6));

      // Should have extra time type records
      final extraTimeRecords = mockData.timingData.records
          .where((r) => r.type == RecordType.extraTime)
          .toList();
      expect(extraTimeRecords.length, equals(1));

      // Should have conflict records
      final conflictRecords =
          mockData.timingData.records.where((r) => r.conflict != null).toList();
      expect(conflictRecords.length, greaterThan(0));
    });

    test('generates mixed conflicts scenario', () {
      final mockData = MockDataGenerator.generateRaceScenario(
        scenario: MockScenarioType.mixed,
        runnerCount: 10,
      );

      expect(mockData.runners.length, equals(10));
      expect(mockData.scenarioName, equals('Mixed Conflicts Scenario'));

      // Should have both missing and extra time conflicts
      final missingTimeRecords = mockData.timingData.records
          .where((r) => r.type == RecordType.missingTime)
          .toList();
      expect(missingTimeRecords.length, greaterThan(0));

      final extraTimeRecords = mockData.timingData.records
          .where((r) => r.type == RecordType.extraTime)
          .toList();
      expect(extraTimeRecords.length, greaterThan(0));

      // Should have TBD record
      final tbdRecords = mockData.timingData.records
          .where((r) => r.elapsedTime == 'TBD')
          .toList();
      expect(tbdRecords.length, greaterThan(0));
    });

    test('generates complex scenario with multiple conflicts', () {
      final mockData = MockDataGenerator.generateRaceScenario(
        scenario: MockScenarioType.complex,
        runnerCount: 12,
      );

      expect(mockData.runners.length, equals(12));
      expect(mockData.scenarioName, equals('Complex Scenario'));

      // Should have multiple conflict types (3 missing time + 4 extra time = 7 total)
      final conflictRecords =
          mockData.timingData.records.where((r) => r.conflict != null).toList();
      expect(conflictRecords.length, equals(7));

      // Should have 2 TBD records (places 2-3)
      final tbdRecords = mockData.timingData.records
          .where((r) => r.elapsedTime == 'TBD')
          .toList();
      expect(tbdRecords.length, equals(2));

      // Should have 1 extra time record
      final extraTimeRecords = mockData.timingData.records
          .where((r) => r.type == RecordType.extraTime)
          .toList();
      expect(extraTimeRecords.length, equals(1));

      // Should have missing time records
      final missingTimeRecords = mockData.timingData.records
          .where((r) => r.type == RecordType.missingTime)
          .toList();
      expect(missingTimeRecords.length, equals(1));
    });

    test('generates realistic runner data', () {
      final mockData = MockDataGenerator.generateRaceScenario(
        scenario: MockScenarioType.clean,
        runnerCount: 5,
      );

      for (int i = 0; i < mockData.runners.length; i++) {
        final runner = mockData.runners[i];

        // Verify runner has required fields
        expect(runner.runnerId, equals(i + 1));
        expect(runner.bib, isNotEmpty);
        expect(runner.name, isNotEmpty);
        expect(runner.team, isNotEmpty);
        expect(runner.teamAbbreviation, isNotEmpty);
        expect(runner.grade, greaterThan(0));

        // Verify bib number format (should be 3 digits)
        expect(runner.bib.length, equals(3));
        expect(int.tryParse(runner.bib), isNotNull);
      }
    });

    test('generates preset scenarios', () {
      final presetScenarios = MockDataGenerator.getPresetScenarios();

      expect(presetScenarios.length, equals(5));

      // Verify each scenario has different characteristics
      final scenarioNames = presetScenarios.map((s) => s.scenarioName).toSet();
      expect(scenarioNames.length, equals(5)); // All unique names

      // Verify each scenario has proper data
      for (final scenario in presetScenarios) {
        expect(scenario.runners.length, greaterThan(0));
        expect(scenario.timingData.records.length, greaterThan(0));
        expect(scenario.scenarioName, isNotEmpty);
        expect(scenario.description, isNotEmpty);
      }
    });

    test('conflict summary is accurate', () {
      final cleanData = MockDataGenerator.generateRaceScenario(
        scenario: MockScenarioType.clean,
        runnerCount: 5,
      );
      expect(cleanData.conflictSummary, equals('No conflicts'));

      final conflictData = MockDataGenerator.generateRaceScenario(
        scenario: MockScenarioType.mixed,
        runnerCount: 8,
      );
      expect(conflictData.conflictSummary, contains('conflict'));
    });

    test('timing data has required endTime', () {
      final mockData = MockDataGenerator.generateRaceScenario(
        scenario: MockScenarioType.clean,
        runnerCount: 5,
      );

      expect(mockData.timingData.endTime, isNotEmpty);
      expect(mockData.timingData.endTime, contains('.'));
    });

    test('places are sequential and valid', () {
      final mockData = MockDataGenerator.generateRaceScenario(
        scenario: MockScenarioType.clean,
        runnerCount: 8,
      );

      final runnerTimeRecords = mockData.timingData.records
          .where((r) => r.type == RecordType.runnerTime)
          .toList();

      // Sort by place to verify sequence
      runnerTimeRecords.sort((a, b) => (a.place ?? 0).compareTo(b.place ?? 0));

      for (int i = 0; i < runnerTimeRecords.length; i++) {
        expect(runnerTimeRecords[i].place, equals(i + 1));
      }
    });
  });
}
