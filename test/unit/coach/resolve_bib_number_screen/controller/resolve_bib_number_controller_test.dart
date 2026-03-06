import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/resolve_bib_number_screen/controller/resolve_bib_number_controller.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/shared/models/database/i_master_race_resolver.dart';
import 'package:xceleration/shared/models/database/race_participant.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

import 'resolve_bib_number_controller_test.mocks.dart';

@GenerateMocks([IMasterRaceResolver])
void main() {
  late MockIMasterRaceResolver mockMasterRace;

  final testTeam = const Team(teamId: 1, name: 'Eagles', abbreviation: 'EAG');
  final anotherTeam =
      const Team(teamId: 2, name: 'Tigers', abbreviation: 'TIG');

  final runnerA = const Runner(
      runnerId: 10, bibNumber: '42', name: 'Alice', grade: 10);
  final runnerB = const Runner(
      runnerId: 11, bibNumber: '99', name: 'Bob', grade: 11);

  final raceRunnerA = RaceRunner(raceId: 1, runner: runnerA, team: testTeam);
  final raceRunnerB = RaceRunner(raceId: 1, runner: runnerB, team: anotherTeam);

  // The runner whose bib triggered the conflict — used as raceRunner param
  final conflictRunner =
      RaceRunner(raceId: 1, runner: runnerA, team: testTeam);

  setUpAll(() {
    provideDummy<Runner>(const Runner());
    provideDummy<RaceParticipant>(const RaceParticipant());
  });

  ResolveBibNumberController buildController({
    List<RaceRunner>? recordedRunners,
  }) {
    return ResolveBibNumberController(
      raceRunners: recordedRunners ?? [],
      raceId: 1,
      onComplete: (_) {},
      raceRunner: conflictRunner,
      masterRace: mockMasterRace,
    );
  }

  setUp(() {
    mockMasterRace = MockIMasterRaceResolver();
  });

  group('ResolveBibNumberController', () {
    group('searchRunners', () {
      test('returns all race runners when query is empty', () async {
        final controller = buildController();
        when(mockMasterRace.raceRunners)
            .thenAnswer((_) async => [raceRunnerA, raceRunnerB]);

        await controller.searchRunners('');

        expect(controller.searchResults, equals([raceRunnerA, raceRunnerB]));
        controller.dispose();
      });

      test('excludes already-recorded bibs when query is empty', () async {
        final controller = buildController(recordedRunners: [raceRunnerA]);
        when(mockMasterRace.raceRunners)
            .thenAnswer((_) async => [raceRunnerA, raceRunnerB]);

        await controller.searchRunners('');

        expect(controller.searchResults, equals([raceRunnerB]));
        expect(controller.searchResults
            .any((r) => r.runner.bibNumber == '42'), isFalse);
        controller.dispose();
      });

      test('calls searchRaceRunners and returns filtered results when query is non-empty',
          () async {
        final controller = buildController();
        when(mockMasterRace.searchRaceRunners(any))
            .thenAnswer((_) async {});
        when(mockMasterRace.filteredSearchResults)
            .thenAnswer((_) async => {testTeam: [raceRunnerA]});

        await controller.searchRunners('alice');

        verify(mockMasterRace.searchRaceRunners('alice')).called(1);
        expect(controller.searchResults, equals([raceRunnerA]));
        controller.dispose();
      });

      test('excludes already-recorded bibs from filtered search results',
          () async {
        final controller = buildController(recordedRunners: [raceRunnerA]);
        when(mockMasterRace.searchRaceRunners(any))
            .thenAnswer((_) async {});
        when(mockMasterRace.filteredSearchResults).thenAnswer(
            (_) async => {testTeam: [raceRunnerA], anotherTeam: [raceRunnerB]});

        await controller.searchRunners('bob');

        expect(controller.searchResults, equals([raceRunnerB]));
        controller.dispose();
      });
    });

    group('createNewRunner', () {
      test('returns error when name is empty', () async {
        final controller = buildController();
        controller.gradeController.text = '10';
        controller.teamController.text = 'Eagles';
        controller.bibController.text = '42';

        final error = await controller.createNewRunner();

        expect(error, isA<AppError>());
        controller.dispose();
      });

      test('returns error when grade is empty', () async {
        final controller = buildController();
        controller.nameController.text = 'Alice';
        controller.teamController.text = 'Eagles';
        controller.bibController.text = '42';

        final error = await controller.createNewRunner();

        expect(error, isA<AppError>());
        controller.dispose();
      });

      test('returns error when team is empty', () async {
        final controller = buildController();
        controller.nameController.text = 'Alice';
        controller.gradeController.text = '10';
        controller.bibController.text = '42';

        final error = await controller.createNewRunner();

        expect(error, isA<AppError>());
        controller.dispose();
      });

      test('returns error when bib is empty', () async {
        final controller = buildController();
        controller.nameController.text = 'Alice';
        controller.gradeController.text = '10';
        controller.teamController.text = 'Eagles';

        final error = await controller.createNewRunner();

        expect(error, isA<AppError>());
        controller.dispose();
      });

      test('calls onComplete and returns null when runner does not exist in db',
          () async {
        RaceRunner? completed;
        final controller = ResolveBibNumberController(
          raceRunners: [],
          raceId: 1,
          onComplete: (r) => completed = r,
          raceRunner: conflictRunner,
          masterRace: mockMasterRace,
        );
        controller.nameController.text = 'Alice';
        controller.gradeController.text = '10';
        controller.teamController.text = 'Eagles';
        controller.bibController.text = '55';

        when(mockMasterRace.teams)
            .thenAnswer((_) async => [testTeam, anotherTeam]);
        when(mockMasterRace.getRunnerByBib(any))
            .thenAnswer((_) async => null);
        when(mockMasterRace.createRunner(any))
            .thenAnswer((_) async => 20);
        when(mockMasterRace.addRunnerToTeam(any, any))
            .thenAnswer((_) async {});
        when(mockMasterRace.addRaceParticipant(any))
            .thenAnswer((_) async {});

        final error = await controller.createNewRunner();

        expect(error, isNull);
        expect(completed, isNotNull);
        expect(completed!.runner.bibNumber, equals('55'));
        expect(completed!.runner.name, equals('Alice'));
        controller.dispose();
      });

      test('calls onComplete and returns null when runner already exists in db',
          () async {
        RaceRunner? completed;
        final existingRunner =
            const Runner(runnerId: 99, bibNumber: '55', name: 'Alice', grade: 10);
        final controller = ResolveBibNumberController(
          raceRunners: [],
          raceId: 1,
          onComplete: (r) => completed = r,
          raceRunner: conflictRunner,
          masterRace: mockMasterRace,
        );
        controller.nameController.text = 'Alice';
        controller.gradeController.text = '10';
        controller.teamController.text = 'Eagles';
        controller.bibController.text = '55';

        when(mockMasterRace.teams)
            .thenAnswer((_) async => [testTeam]);
        when(mockMasterRace.getRunnerByBib(any))
            .thenAnswer((_) async => existingRunner);
        when(mockMasterRace.addRaceParticipant(any))
            .thenAnswer((_) async {});

        final error = await controller.createNewRunner();

        expect(error, isNull);
        expect(completed, isNotNull);
        expect(completed!.runner.runnerId, equals(99));
        verifyNever(mockMasterRace.createRunner(any));
        controller.dispose();
      });

      test('returns error when an exception is thrown', () async {
        final controller = buildController();
        controller.nameController.text = 'Alice';
        controller.gradeController.text = '10';
        controller.teamController.text = 'Eagles';
        controller.bibController.text = '55';

        when(mockMasterRace.teams).thenThrow(Exception('db error'));

        final error = await controller.createNewRunner();

        expect(error, isA<AppError>());
        controller.dispose();
      });
    });

    group('assignExistingRaceRunner', () {
      test('returns error when bib is already assigned to a recorded runner',
          () async {
        final controller = buildController(recordedRunners: [raceRunnerA]);

        final error = controller.assignExistingRaceRunner(raceRunnerA);

        expect(error, isA<AppError>());
        expect(error!.userMessage,
            contains('already assigned'));
        controller.dispose();
      });

      test('calls onComplete and returns null when bib is not already assigned',
          () async {
        RaceRunner? completed;
        final controller = ResolveBibNumberController(
          raceRunners: [raceRunnerA],
          raceId: 1,
          onComplete: (r) => completed = r,
          raceRunner: conflictRunner,
          masterRace: mockMasterRace,
        );

        final error = controller.assignExistingRaceRunner(raceRunnerB);

        expect(error, isNull);
        expect(completed, equals(raceRunnerB));
        controller.dispose();
      });
    });
  });
}
