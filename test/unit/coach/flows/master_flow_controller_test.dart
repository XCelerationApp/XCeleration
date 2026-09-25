import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/flows/post_race_flow/controller/post_race_controller.dart';
import 'package:xceleration/coach/flows/pre_race_flow/controller/pre_race_controller.dart';
import 'package:xceleration/coach/flows/controller/flow_controller.dart';
import 'package:xceleration/coach/race_screen/controller/race_form_state.dart';
import 'package:xceleration/coach/race_screen/controller/race_screen_controller.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race.dart';
import 'package:xceleration/coach/race_screen/services/race_service.dart';

@GenerateMocks([
  RaceScreenController,
  PreRaceController,
  PostRaceController,
  MasterRace,
])
import 'master_flow_controller_test.mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal widget tree with a Navigator and returns a live [BuildContext].
Future<BuildContext> _buildContext(WidgetTester tester) async {
  BuildContext? ctx;
  // A Scaffold, as in the app, to show "what happens next" on.
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(builder: (context) {
        ctx = context;
        return const SizedBox();
      }),
    ),
  ));
  return ctx!;
}

final _testRace =
    Race(raceId: 1, raceName: 'Test Race', flowState: Race.FLOW_PRE_RACE);

// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRaceScreenController mockRaceController;
  late MockPreRaceController mockPreRaceController;
  late MockPostRaceController mockPostRaceController;
  late MockMasterRace mockMasterRace;
  late RaceFormState fakeForm;
  late MasterFlowController controller;

  setUp(() {
    mockRaceController = MockRaceScreenController();
    mockPreRaceController = MockPreRaceController();
    mockPostRaceController = MockPostRaceController();
    mockMasterRace = MockMasterRace();
    fakeForm = RaceFormState();

    when(mockRaceController.masterRace).thenReturn(mockMasterRace);
    when(mockMasterRace.raceId).thenReturn(1);
    when(mockMasterRace.race).thenAnswer((_) async => _testRace);
    when(mockMasterRace.teams).thenAnswer((_) async => []);
    when(mockMasterRace.raceRunners).thenAnswer((_) async => []);
    when(mockMasterRace.teamtoRaceRunnersMap).thenAnswer((_) async => {});
    when(mockRaceController.form).thenReturn(fakeForm);
    when(mockRaceController.teamsOrNull).thenReturn(null);
    when(mockRaceController.updateRaceFlowState(any, any))
        .thenAnswer((_) async {});

    controller = MasterFlowController(
      raceController: mockRaceController,
      preRaceController: mockPreRaceController,
      postRaceController: mockPostRaceController,
      raceService: RaceService(),
    );
  });

  tearDown(() {
    fakeForm.dispose();
  });

  // =========================================================================
  group('MasterFlowController', () {
    // -----------------------------------------------------------------------
    group('updateRaceFlowState', () {
      testWidgets('delegates to raceController.updateRaceFlowState',
          (tester) async {
        final context = await _buildContext(tester);

        await controller.updateRaceFlowState(
            context, Race.FLOW_PRE_RACE_COMPLETED);

        verify(mockRaceController.updateRaceFlowState(
                any, Race.FLOW_PRE_RACE_COMPLETED))
            .called(1);
      });
    });

    // -----------------------------------------------------------------------
    group('markCurrentFlowCompleted', () {
      testWidgets(
          'calls raceController.updateRaceFlowState with the completed state',
          (tester) async {
        final context = await _buildContext(tester);
        // _testRace.flowState = FLOW_PRE_RACE → completedFlowState = FLOW_PRE_RACE_COMPLETED
        when(mockMasterRace.race).thenAnswer((_) async => _testRace);

        await controller.markCurrentFlowCompleted(context);

        verify(mockRaceController.updateRaceFlowState(
                any, Race.FLOW_PRE_RACE_COMPLETED))
            .called(1);
      });

      testWidgets('is a no-op when context is not mounted', (tester) async {
        BuildContext? capturedCtx;
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (ctx) {
            capturedCtx = ctx;
            return const SizedBox();
          }),
        ));
        await tester.pumpWidget(const SizedBox());

        await controller.markCurrentFlowCompleted(capturedCtx!);

        verifyNever(mockRaceController.updateRaceFlowState(any, any));
      });
    });

    // -----------------------------------------------------------------------
    group('beginNextFlow', () {
      testWidgets('advances from FLOW_SETUP_COMPLETED to FLOW_PRE_RACE',
          (tester) async {
        final context = await _buildContext(tester);
        final setupCompletedRace = Race(
          raceId: 1,
          raceName: 'Test Race',
          flowState: Race.FLOW_SETUP_COMPLETED,
        );
        when(mockMasterRace.race).thenAnswer((_) async => setupCompletedRace);
        when(mockPreRaceController.showPreRaceFlow(any, any))
            .thenAnswer((_) async => false);

        await controller.beginNextFlow(context);

        verify(mockRaceController.updateRaceFlowState(any, Race.FLOW_PRE_RACE))
            .called(1);
      });

      testWidgets('is a no-op when context is not mounted', (tester) async {
        BuildContext? capturedCtx;
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (ctx) {
            capturedCtx = ctx;
            return const SizedBox();
          }),
        ));
        await tester.pumpWidget(const SizedBox());

        await controller.beginNextFlow(capturedCtx!);

        verifyNever(mockRaceController.updateRaceFlowState(any, any));
      });
    });

    // -----------------------------------------------------------------------
    group('continueRaceFlow', () {
      testWidgets('is a no-op when context is not mounted', (tester) async {
        BuildContext? capturedCtx;
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (ctx) {
            capturedCtx = ctx;
            return const SizedBox();
          }),
        ));
        await tester.pumpWidget(const SizedBox());

        await controller.continueRaceFlow(capturedCtx!);

        verifyNever(mockPreRaceController.showPreRaceFlow(any, any));
        verifyNever(mockPostRaceController.showPostRaceFlow(any, any));
      });

      testWidgets(
          'FLOW_SETUP with incomplete setup: shows dialog, does not advance',
          (tester) async {
        final context = await _buildContext(tester);
        final setupRace = Race(
            raceId: 1, raceName: 'Test Race', flowState: Race.FLOW_SETUP);
        when(mockMasterRace.race).thenAnswer((_) async => setupRace);
        // form fields are empty → canAdvance = false
        fakeForm.nameController.text = '';

        await controller.continueRaceFlow(context);
        await tester.pumpAndSettle();

        verifyNever(mockRaceController.updateRaceFlowState(any, any));
        expect(find.text('Got it'), findsOneWidget);
      });

      /// Runs continueRaceFlow, answering its confirmation with [answer].
      Future<void> run(WidgetTester tester, BuildContext context,
          {required String answer}) async {
        final future = controller.continueRaceFlow(context);
        await tester.pumpAndSettle();
        await tester.tap(find.text(answer));
        await tester.pumpAndSettle();
        await future;
        // Lets the "what happens next" toast run out.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }

      testWidgets(
          'FLOW_SETUP_COMPLETED: asks if ready, then sends (FLOW_PRE_RACE)',
          (tester) async {
        final context = await _buildContext(tester);
        when(mockMasterRace.race).thenAnswer((_) async => Race(
              raceId: 1,
              raceName: 'Test Race',
              flowState: Race.FLOW_SETUP_COMPLETED,
            ));
        when(mockPreRaceController.showPreRaceFlow(any, any))
            .thenAnswer((_) async => false);

        final future = controller.continueRaceFlow(context);
        await tester.pumpAndSettle();
        expect(find.text('Ready to Send the Race?'), findsOneWidget);
        expect(find.textContaining('You are at the race'), findsOneWidget);
        await tester.tap(find.text('Send Race'));
        await tester.pumpAndSettle();
        await future;

        verify(mockRaceController.updateRaceFlowState(any, Race.FLOW_PRE_RACE))
            .called(1);
        verify(mockPreRaceController.showPreRaceFlow(any, any)).called(1);
      });

      testWidgets('Not Yet leaves the race where it was', (tester) async {
        final context = await _buildContext(tester);
        when(mockMasterRace.race).thenAnswer((_) async => Race(
              raceId: 1,
              raceName: 'Test Race',
              flowState: Race.FLOW_SETUP_COMPLETED,
            ));

        await run(tester, context, answer: 'Not Yet');

        verifyNever(mockRaceController.updateRaceFlowState(any, any));
        verifyNever(mockPreRaceController.showPreRaceFlow(any, any));
      });

      testWidgets('FLOW_PRE_RACE: asks, then delegates to preRaceFlow',
          (tester) async {
        final context = await _buildContext(tester);
        when(mockRaceController.flowState).thenReturn(Race.FLOW_PRE_RACE);
        when(mockMasterRace.race).thenAnswer((_) async => _testRace);
        when(mockPreRaceController.showPreRaceFlow(any, any))
            .thenAnswer((_) async => false);

        await run(tester, context, answer: 'Send Race');

        verify(mockPreRaceController.showPreRaceFlow(any, any)).called(1);
        verifyNever(mockPostRaceController.showPostRaceFlow(any, any));
      });

      testWidgets('FLOW_PRE_RACE_COMPLETED: asks if every runner is in, then '
          'collects (FLOW_POST_RACE)', (tester) async {
        final context = await _buildContext(tester);
        when(mockMasterRace.race).thenAnswer((_) async => Race(
              raceId: 1,
              raceName: 'Test Race',
              flowState: Race.FLOW_PRE_RACE_COMPLETED,
            ));
        when(mockPostRaceController.showPostRaceFlow(any, any))
            .thenAnswer((_) async => false);

        final future = controller.continueRaceFlow(context);
        await tester.pumpAndSettle();
        expect(find.text('Ready to Collect Results?'), findsOneWidget);
        expect(find.textContaining('Every runner has finished'), findsOneWidget);
        await tester.tap(find.text('Collect Results'));
        await tester.pumpAndSettle();
        await future;

        verify(mockRaceController.updateRaceFlowState(any, Race.FLOW_POST_RACE))
            .called(1);
        verify(mockPostRaceController.showPostRaceFlow(any, any)).called(1);
      });

      testWidgets('FLOW_POST_RACE: asks, then delegates to postRaceFlow',
          (tester) async {
        final context = await _buildContext(tester);
        when(mockMasterRace.race).thenAnswer((_) async => Race(
            raceId: 1, raceName: 'Test Race', flowState: Race.FLOW_POST_RACE));
        when(mockPostRaceController.showPostRaceFlow(any, any))
            .thenAnswer((_) async => false);

        await run(tester, context, answer: 'Collect Results');

        verify(mockPostRaceController.showPostRaceFlow(any, any)).called(1);
        verifyNever(mockPreRaceController.showPreRaceFlow(any, any));
      });

      testWidgets(
          '_preRaceFlow complete → updateRaceFlowState called with FLOW_PRE_RACE_COMPLETED',
          (tester) async {
        final context = await _buildContext(tester);
        when(mockRaceController.flowState).thenReturn(Race.FLOW_PRE_RACE);
        when(mockMasterRace.race).thenAnswer((_) async => _testRace);
        when(mockPreRaceController.showPreRaceFlow(any, any))
            .thenAnswer((_) async => true);

        await run(tester, context, answer: 'Send Race');

        verify(mockRaceController.updateRaceFlowState(
                any, Race.FLOW_PRE_RACE_COMPLETED))
            .called(1);
      });

      testWidgets(
          '_postRaceFlow complete → updateRaceFlowState called with FLOW_FINISHED',
          (tester) async {
        final context = await _buildContext(tester);
        when(mockMasterRace.race).thenAnswer((_) async => Race(
            raceId: 1, raceName: 'Test Race', flowState: Race.FLOW_POST_RACE));
        when(mockPostRaceController.showPostRaceFlow(any, any))
            .thenAnswer((_) async => true);

        await run(tester, context, answer: 'Collect Results');

        verify(mockRaceController.updateRaceFlowState(any, Race.FLOW_FINISHED))
            .called(1);
      });

      testWidgets('closes the race sheet once a step is done, saying what is '
          'next', (tester) async {
        // The race sheet is a route over the races list.
        BuildContext? raceSheet;
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
            builder: (listContext) => TextButton(
              onPressed: () => Navigator.of(listContext).push(
                MaterialPageRoute<void>(builder: (context) {
                  raceSheet = context;
                  return const Scaffold(body: Text('race sheet'));
                }),
              ),
              child: const Text('open race'),
            ),
            ),
          ),
        ));
        await tester.tap(find.text('open race'));
        await tester.pumpAndSettle();
        when(mockRaceController.flowState).thenReturn(Race.FLOW_PRE_RACE);
        when(mockMasterRace.race).thenAnswer((_) async => _testRace);
        when(mockPreRaceController.showPreRaceFlow(any, any))
            .thenAnswer((_) async => true);

        final future = controller.continueRaceFlow(raceSheet!);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Send Race'));
        await tester.pump();
        await future;
        await tester.pump();

        expect(find.textContaining('Race sent'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text('race sheet'), findsNothing);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      });
    });

    // -----------------------------------------------------------------------
    group('handleFlowNavigation', () {
      testWidgets(
          'returns true and animates to tab 0 for a completed-suffix state',
          (tester) async {
        final context = await _buildContext(tester);
        final tabController =
            TabController(length: 2, vsync: tester, initialIndex: 1);
        when(mockRaceController.tabController).thenReturn(tabController);

        final result = await controller.handleFlowNavigation(
            context, Race.FLOW_PRE_RACE_COMPLETED);

        expect(result, isTrue);
        await tester.pumpAndSettle();
        expect(tabController.index, 0);
        tabController.dispose();
      });

      testWidgets('returns true and animates to tab 0 for FLOW_FINISHED',
          (tester) async {
        final context = await _buildContext(tester);
        final tabController =
            TabController(length: 2, vsync: tester, initialIndex: 1);
        when(mockRaceController.tabController).thenReturn(tabController);

        final result =
            await controller.handleFlowNavigation(context, Race.FLOW_FINISHED);

        expect(result, isTrue);
        await tester.pumpAndSettle();
        expect(tabController.index, 0);
        tabController.dispose();
      });

      testWidgets('returns false for unknown flow state', (tester) async {
        final context = await _buildContext(tester);

        final result =
            await controller.handleFlowNavigation(context, 'unknown-state');

        expect(result, isFalse);
      });

      testWidgets('delegates to preRaceFlow for FLOW_PRE_RACE', (tester) async {
        final context = await _buildContext(tester);
        when(mockPreRaceController.showPreRaceFlow(any, any))
            .thenAnswer((_) async => false);

        await controller.handleFlowNavigation(context, Race.FLOW_PRE_RACE);

        verify(mockPreRaceController.showPreRaceFlow(any, any)).called(1);
        verifyNever(mockPostRaceController.showPostRaceFlow(any, any));
      });

      testWidgets('delegates to postRaceFlow for FLOW_POST_RACE',
          (tester) async {
        final context = await _buildContext(tester);
        when(mockPostRaceController.showPostRaceFlow(any, any))
            .thenAnswer((_) async => false);

        await controller.handleFlowNavigation(context, Race.FLOW_POST_RACE);

        verify(mockPostRaceController.showPostRaceFlow(any, any)).called(1);
        verifyNever(mockPreRaceController.showPreRaceFlow(any, any));
      });
    });
  });
}
