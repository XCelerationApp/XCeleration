import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/runners_management_screen/controller/runners_management_controller.dart';
import 'package:xceleration/core/utils/database_helper.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/base_models.dart';

@GenerateMocks([MasterRace, DatabaseHelper])
import 'runners_management_controller_test.mocks.dart';

Future<BuildContext> _buildContext(WidgetTester tester) async {
  BuildContext? ctx;
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (context) {
      ctx = context;
      return const SizedBox();
    }),
  ));
  return ctx!;
}

void main() {
  late MockMasterRace mockMasterRace;
  late MockDatabaseHelper mockDb;
  late RunnersManagementController controller;

  const testTeam = Team(
    teamId: 1,
    name: 'Team A',
    abbreviation: 'TA',
    color: Color(0xFF2196F3),
  );

  final testRunner = Runner(
    runnerId: 1,
    name: 'Alice',
    bibNumber: '101',
    grade: 10,
  );

  final testRaceRunner = RaceRunner(
    raceId: 1,
    runner: testRunner,
    team: testTeam,
  );

  setUp(() {
    mockMasterRace = MockMasterRace();
    mockDb = MockDatabaseHelper();

    when(mockMasterRace.raceId).thenReturn(1);
    when(mockMasterRace.db).thenReturn(mockDb);
    when(mockMasterRace.raceRunners).thenAnswer((_) async => [testRaceRunner]);
    when(mockMasterRace.searchRaceRunners(any, any)).thenAnswer((_) async {});

    controller = RunnersManagementController(masterRace: mockMasterRace);
  });

  tearDown(() {
    controller.dispose();
  });

  group('RunnersManagementController', () {
    // -------------------------------------------------------------------------
    group('loadData', () {
      test('transitions isLoading true then false on success', () async {
        final loadingStates = <bool>[];
        controller.addListener(() => loadingStates.add(controller.isLoading));

        await controller.loadData();

        expect(loadingStates.first, isTrue);
        expect(loadingStates.last, isFalse);
        expect(controller.isLoading, isFalse);
      });

      test('loads raceRunners from masterRace', () async {
        await controller.loadData();

        verify(mockMasterRace.raceRunners).called(greaterThanOrEqualTo(1));
      });

      test('sets isLoading to false on error', () async {
        when(mockMasterRace.raceRunners).thenAnswer((_) async => throw Exception('db error'));

        await controller.loadData();

        expect(controller.isLoading, isFalse);
      });

      test('calls onContentChanged callback after successful load', () async {
        var called = false;
        final ctrl = RunnersManagementController(
          masterRace: mockMasterRace,
          onContentChanged: () => called = true,
        );
        addTearDown(ctrl.dispose);

        await ctrl.loadData();

        expect(called, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    group('filterRaceRunners', () {
      test('calls searchRaceRunners with all for default searchAttribute', () async {
        controller.filterRaceRunners('alice');
        await Future.delayed(Duration.zero);

        verify(mockMasterRace.searchRaceRunners('alice', 'all')).called(greaterThanOrEqualTo(1));
      });

      test('maps Bib Number searchAttribute to bib', () async {
        controller.searchAttribute = 'Bib Number';
        controller.filterRaceRunners('101');
        await Future.delayed(Duration.zero);

        verify(mockMasterRace.searchRaceRunners('101', 'bib')).called(greaterThanOrEqualTo(1));
      });

      test('maps Name searchAttribute to name', () async {
        controller.searchAttribute = 'Name';
        controller.filterRaceRunners('alice');
        await Future.delayed(Duration.zero);

        verify(mockMasterRace.searchRaceRunners('alice', 'name')).called(greaterThanOrEqualTo(1));
      });

      test('maps Grade searchAttribute to grade', () async {
        controller.searchAttribute = 'Grade';
        controller.filterRaceRunners('10');
        await Future.delayed(Duration.zero);

        verify(mockMasterRace.searchRaceRunners('10', 'grade')).called(greaterThanOrEqualTo(1));
      });

      test('maps Team searchAttribute to team', () async {
        controller.searchAttribute = 'Team';
        controller.filterRaceRunners('Team A');
        await Future.delayed(Duration.zero);

        verify(mockMasterRace.searchRaceRunners('Team A', 'team')).called(greaterThanOrEqualTo(1));
      });
    });

    // -------------------------------------------------------------------------
    group('deleteRaceRunner', () {
      test('calls masterRace.removeRaceRunner with the given runner', () async {
        when(mockMasterRace.removeRaceRunner(any)).thenAnswer((_) async {});

        await controller.deleteRaceRunner(testRaceRunner);

        verify(mockMasterRace.removeRaceRunner(testRaceRunner)).called(1);
      });

      test('calls onContentChanged after deletion', () async {
        when(mockMasterRace.removeRaceRunner(any)).thenAnswer((_) async {});
        var called = false;
        final ctrl = RunnersManagementController(
          masterRace: mockMasterRace,
          onContentChanged: () => called = true,
        );
        addTearDown(ctrl.dispose);

        await ctrl.deleteRaceRunner(testRaceRunner);

        expect(called, isTrue);
      });

      test('throws exception when removeRaceRunner fails', () async {
        when(mockMasterRace.removeRaceRunner(any))
            .thenAnswer((_) async => throw Exception('delete failed'));

        await expectLater(
          controller.deleteRaceRunner(testRaceRunner),
          throwsException,
        );
      });
    });

    // -------------------------------------------------------------------------
    group('createTeam', () {
      test('does nothing when team name is null', () async {
        await controller.createTeam(const Team());

        verifyNever(mockDb.createTeam(any));
      });

      test('does nothing when team name is empty', () async {
        await controller.createTeam(const Team(name: '  '));

        verifyNever(mockDb.createTeam(any));
      });

      test('does nothing when team already exists', () async {
        const existingTeam = Team(teamId: 1, name: 'Team A', abbreviation: 'TA');
        when(mockMasterRace.getTeamByName('Team A')).thenAnswer((_) async => existingTeam);

        await controller.createTeam(const Team(name: 'Team A', abbreviation: 'TA'));

        verifyNever(mockDb.createTeam(any));
      });

      test('creates team and adds team participant when team does not exist', () async {
        when(mockMasterRace.getTeamByName('New Team')).thenAnswer((_) async => null);
        when(mockDb.createTeam(any)).thenAnswer((_) async => 2);
        when(mockMasterRace.addTeamParticipant(any)).thenAnswer((_) async {});

        await controller.createTeam(const Team(
          teamId: 2,
          name: 'New Team',
          abbreviation: 'NT',
          color: Color(0xFF2196F3),
        ));

        verify(mockDb.createTeam(any)).called(1);
        verify(mockMasterRace.addTeamParticipant(any)).called(1);

        // Allow the unawaited loadData() fired inside createTeam to complete
        // before tearDown disposes the controller.
        await Future.delayed(Duration.zero);
      });
    });

    // -------------------------------------------------------------------------
    group('handleRunnerSubmission', () {
      group('new runner path (runnerId == null)', () {
        testWidgets('creates runner, adds to team roster and race', (tester) async {
          final ctx = await _buildContext(tester);
          final newRaceRunner = RaceRunner(
            raceId: 1,
            runner: const Runner(name: 'Bob', bibNumber: '202', grade: 11),
            team: testTeam,
          );

          when(mockDb.getRunnerByBib('202')).thenAnswer((_) async => null);
          when(mockDb.createRunner(any)).thenAnswer((_) async => 5);
          when(mockDb.addRunnerToTeam(any, any)).thenAnswer((_) async {});
          when(mockMasterRace.addRaceParticipant(any)).thenAnswer((_) async {});
          when(mockMasterRace.searchRaceRunners(any, any)).thenAnswer((_) async {});

          await controller.handleRunnerSubmission(ctx, newRaceRunner);

          verify(mockDb.createRunner(any)).called(1);
          verify(mockDb.addRunnerToTeam(1, 5)).called(1);
          verify(mockMasterRace.addRaceParticipant(any)).called(1);
        });
      });

      group('existing runner path (runnerId != null, same bib)', () {
        testWidgets('updates existing runner and race participant', (tester) async {
          final ctx = await _buildContext(tester);
          final existingRaceRunner = RaceRunner(
            raceId: 1,
            runner: Runner(runnerId: 3, name: 'Carol Updated', bibNumber: '303', grade: 12),
            team: testTeam,
          );
          // Same runner (runnerId matches) → no bib conflict
          when(mockDb.getRunnerByBib('303')).thenAnswer((_) async =>
              Runner(runnerId: 3, name: 'Carol', bibNumber: '303', grade: 12));
          when(mockDb.updateRunnerWithTeams(
            runner: anyNamed('runner'),
            newTeamId: anyNamed('newTeamId'),
            raceIdForTeamUpdate: anyNamed('raceIdForTeamUpdate'),
          )).thenAnswer((_) async {});
          when(mockDb.getRunnersByBibAll('303')).thenAnswer((_) async => []);
          when(mockMasterRace.updateRaceParticipant(any)).thenAnswer((_) async {});
          when(mockMasterRace.searchRaceRunners(any, any)).thenAnswer((_) async {});

          await controller.handleRunnerSubmission(ctx, existingRaceRunner);

          verify(mockDb.updateRunnerWithTeams(
            runner: anyNamed('runner'),
            newTeamId: anyNamed('newTeamId'),
            raceIdForTeamUpdate: anyNamed('raceIdForTeamUpdate'),
          )).called(1);
          verify(mockMasterRace.updateRaceParticipant(any)).called(1);
        });
      });

      group('bib conflict path (bib owned by different runner)', () {
        testWidgets('updates conflict runner and deletes the old distinct runner', (tester) async {
          final ctx = await _buildContext(tester);
          // raceRunner has runnerId=1, but bib 404 is already owned by runnerId=9
          final conflictingRaceRunner = RaceRunner(
            raceId: 1,
            runner: Runner(runnerId: 1, name: 'Dave', bibNumber: '404', grade: 10),
            team: testTeam,
          );
          final conflictRunner = Runner(runnerId: 9, name: 'Eve', bibNumber: '404', grade: 11);

          when(mockDb.getRunnerByBib('404')).thenAnswer((_) async => conflictRunner);
          // Race participant lookup for old runner (runnerId=1)
          when(mockDb.getRaceParticipant(any)).thenAnswer((_) async => null);
          when(mockDb.updateRunner(any)).thenAnswer((_) async {});
          when(mockDb.setRunnerTeam(any, any)).thenAnswer((_) async {});
          when(mockMasterRace.addRaceParticipant(any)).thenAnswer((_) async {});
          when(mockDb.deleteRunnerEverywhere(any)).thenAnswer((_) async {});
          when(mockMasterRace.searchRaceRunners(any, any)).thenAnswer((_) async {});

          await controller.handleRunnerSubmission(ctx, conflictingRaceRunner);

          // Existing conflict runner (9) was updated with submitted details
          verify(mockDb.updateRunner(any)).called(1);
          // Old distinct runner (1) was deleted globally
          verify(mockDb.deleteRunnerEverywhere(1)).called(1);
        });
      });
    });
  });
}
