import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/flows/PostRaceFlow/controller/post_race_controller.dart';
import 'package:xceleration/coach/flows/PreRaceFlow/controller/pre_race_controller.dart';
import 'package:xceleration/coach/flows/controller/flow_controller.dart';
import 'package:xceleration/coach/race_screen/controller/race_screen_controller.dart';
import 'package:xceleration/core/services/event_bus.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race.dart';

@GenerateMocks([
  RaceController,
  PreRaceController,
  PostRaceController,
  EventBus,
  MasterRace,
])
import 'master_flow_controller_test.mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal widget tree with a Navigator and returns a live [BuildContext].
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

final _testRace = Race(raceId: 1, raceName: 'Test Race', flowState: Race.FLOW_PRE_RACE);

// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRaceController mockRaceController;
  late MockPreRaceController mockPreRaceController;
  late MockPostRaceController mockPostRaceController;
  late MockEventBus mockEventBus;
  late MockMasterRace mockMasterRace;
  late MasterFlowController controller;

  setUp(() {
    mockRaceController = MockRaceController();
    mockPreRaceController = MockPreRaceController();
    mockPostRaceController = MockPostRaceController();
    mockEventBus = MockEventBus();
    mockMasterRace = MockMasterRace();

    when(mockRaceController.masterRace).thenReturn(mockMasterRace);
    when(mockMasterRace.raceId).thenReturn(1);
    when(mockMasterRace.race).thenAnswer((_) async => _testRace);

    controller = MasterFlowController(
      raceController: mockRaceController,
      eventBus: mockEventBus,
      preRaceController: mockPreRaceController,
      postRaceController: mockPostRaceController,
    );
  });

  // =========================================================================
  group('MasterFlowController', () {
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
        // Remove the widget tree so the captured context becomes unmounted
        await tester.pumpWidget(const SizedBox());

        await controller.continueRaceFlow(capturedCtx!);

        verifyNever(mockPreRaceController.showPreRaceFlow(any, any));
        verifyNever(mockPostRaceController.showPostRaceFlow(any, any));
      });

      testWidgets('delegates to preRaceFlow when flowState is FLOW_PRE_RACE',
          (tester) async {
        final context = await _buildContext(tester);
        when(mockRaceController.flowState).thenReturn(Race.FLOW_PRE_RACE);
        when(mockPreRaceController.showPreRaceFlow(any, any))
            .thenAnswer((_) async => false);

        await controller.continueRaceFlow(context);

        verify(mockPreRaceController.showPreRaceFlow(any, any)).called(1);
        verifyNever(mockPostRaceController.showPostRaceFlow(any, any));
      });

      testWidgets('delegates to postRaceFlow when flowState is FLOW_POST_RACE',
          (tester) async {
        final context = await _buildContext(tester);
        when(mockRaceController.flowState).thenReturn(Race.FLOW_POST_RACE);
        when(mockPostRaceController.showPostRaceFlow(any, any))
            .thenAnswer((_) async => false);

        await controller.continueRaceFlow(context);

        verify(mockPostRaceController.showPostRaceFlow(any, any)).called(1);
        verifyNever(mockPreRaceController.showPreRaceFlow(any, any));
      });

      testWidgets(
          '_preRaceFlow complete → updateRaceFlowState called with FLOW_PRE_RACE_COMPLETED',
          (tester) async {
        final context = await _buildContext(tester);
        when(mockRaceController.flowState).thenReturn(Race.FLOW_PRE_RACE);
        when(mockPreRaceController.showPreRaceFlow(any, any))
            .thenAnswer((_) async => true);
        when(mockRaceController.updateRaceFlowState(any, any))
            .thenAnswer((_) async {});

        await controller.continueRaceFlow(context);

        verify(mockRaceController.updateRaceFlowState(
                any, Race.FLOW_PRE_RACE_COMPLETED))
            .called(1);
      });

      testWidgets(
          '_postRaceFlow complete → updateRaceFlowState called with FLOW_FINISHED',
          (tester) async {
        final context = await _buildContext(tester);
        when(mockRaceController.flowState).thenReturn(Race.FLOW_POST_RACE);
        when(mockPostRaceController.showPostRaceFlow(any, any))
            .thenAnswer((_) async => true);
        when(mockRaceController.updateRaceFlowState(any, any))
            .thenAnswer((_) async {});
        final tabController = TabController(length: 2, vsync: tester);
        when(mockRaceController.tabController).thenReturn(tabController);

        final future = controller.continueRaceFlow(context);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await future;

        verify(mockRaceController.updateRaceFlowState(any, Race.FLOW_FINISHED))
            .called(1);
        tabController.dispose();
      });

      testWidgets('_postRaceFlow complete → tabController.animateTo(1) called',
          (tester) async {
        final context = await _buildContext(tester);
        when(mockRaceController.flowState).thenReturn(Race.FLOW_POST_RACE);
        when(mockPostRaceController.showPostRaceFlow(any, any))
            .thenAnswer((_) async => true);
        when(mockRaceController.updateRaceFlowState(any, any))
            .thenAnswer((_) async {});
        final tabController =
            TabController(length: 2, vsync: tester, initialIndex: 0);
        when(mockRaceController.tabController).thenReturn(tabController);

        final future = controller.continueRaceFlow(context);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await future;
        await tester.pumpAndSettle();

        expect(tabController.index, 1);
        tabController.dispose();
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

        final result = await controller.handleFlowNavigation(
            context, Race.FLOW_FINISHED);

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

    // -----------------------------------------------------------------------
    group('updateRaceFlowState', () {
      testWidgets('calls raceController.updateRaceFlowState with the new state',
          (tester) async {
        final context = await _buildContext(tester);
        when(mockRaceController.updateRaceFlowState(any, any))
            .thenAnswer((_) async {});

        await controller.updateRaceFlowState(context, Race.FLOW_PRE_RACE_COMPLETED);

        verify(mockRaceController.updateRaceFlowState(
                any, Race.FLOW_PRE_RACE_COMPLETED))
            .called(1);
      });

      testWidgets('fires raceFlowStateChanged event via the injected EventBus',
          (tester) async {
        final context = await _buildContext(tester);
        when(mockRaceController.updateRaceFlowState(any, any))
            .thenAnswer((_) async {});

        await controller.updateRaceFlowState(context, Race.FLOW_PRE_RACE_COMPLETED);

        verify(mockEventBus.fire(EventTypes.raceFlowStateChanged, any))
            .called(1);
      });
    });
  });
}
