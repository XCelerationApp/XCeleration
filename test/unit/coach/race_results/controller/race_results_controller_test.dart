import 'package:flutter_test/flutter_test.dart';
import 'package:xcelerate/coach/race_results/controller/race_results_controller.dart';

void main() {
  group('RaceResultsController Tests', () {
    late RaceResultsController controller;

    setUp(() {
      controller = RaceResultsController(raceId: -999);
    });

    test('should initialize with empty results', () {
      expect(controller.individualResults, isEmpty);
      expect(controller.overallTeamResults, isEmpty);
      expect(controller.headToHeadTeamResults, isEmpty);
    });

    test('getTopRunners should return empty list when no results', () {
      expect(controller.getTopRunners(5), isEmpty);
    });
  });
}
