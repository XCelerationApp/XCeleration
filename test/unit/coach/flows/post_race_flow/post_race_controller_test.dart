import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/flows/post_race_flow/controller/post_race_controller.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/controller/load_results_controller.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/load_results_step.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/reconnect/reconnect_step.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';
import 'package:xceleration/shared/models/database/master_race.dart';

@GenerateMocks([MasterRace, LoadResultsController])
import 'post_race_controller_test.mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PostRaceController _buildController(
  MockMasterRace mockMasterRace, {
  ShowFlowFn? showFlowFn,
  MockLoadResultsController? loadResultsController,
}) {
  return PostRaceController(
    masterRace: mockMasterRace,
    showFlowFn: showFlowFn,
    loadResultsController: loadResultsController,
  );
}

void _stubMasterRace(MockMasterRace mockMasterRace) {
  when(mockMasterRace.results).thenAnswer((_) async => []);
}

void _stubLoadResultsController(
    MockLoadResultsController mockLoadResultsController) {
  when(mockLoadResultsController.initialize()).thenReturn(null);
  when(mockLoadResultsController.addListener(any)).thenReturn(null);
  when(mockLoadResultsController.removeListener(any)).thenReturn(null);
}

// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMasterRace mockMasterRace;
  late MockLoadResultsController mockLoadResultsController;

  setUp(() {
    mockMasterRace = MockMasterRace();
    mockLoadResultsController = MockLoadResultsController();
    _stubMasterRace(mockMasterRace);
    _stubLoadResultsController(mockLoadResultsController);
  });

  // =========================================================================
  group('PostRaceController', () {
    // -----------------------------------------------------------------------
    group('_initializeSteps', () {
      test('builds two steps in the correct order', () {
        final controller = _buildController(
          mockMasterRace,
          loadResultsController: mockLoadResultsController,
        );

        final steps = controller.buildSteps();

        expect(steps.length, 2);
        expect(steps[0], isA<ReconnectStep>());
        expect(steps[1], isA<LoadResultsStep>());
      });

      test('calls initialize() on injected LoadResultsController', () {
        _buildController(
          mockMasterRace,
          loadResultsController: mockLoadResultsController,
        );

        verify(mockLoadResultsController.initialize()).called(1);
      });
    });

    // -----------------------------------------------------------------------
    group('showPostRaceFlow', () {
      testWidgets(
          'starts at 0 on the first call and uses persisted index on the next call',
          (tester) async {
        final capturedIndices = <int>[];

        Future<bool> fakeShowFlow({
          required BuildContext context,
          required List<FlowStep> steps,
          bool showProgressIndicator = true,
          int initialIndex = 0,
          StepChangedCallback? onStepChanged,
          void Function(int lastIndex)? onDismiss,
        }) async {
          capturedIndices.add(initialIndex);
          onDismiss?.call(1); // simulate dismissal at step index 1
          return false;
        }

        final controller = _buildController(
          mockMasterRace,
          showFlowFn: fakeShowFlow,
          loadResultsController: mockLoadResultsController,
        );

        BuildContext? ctx;
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (context) {
            ctx = context;
            return const SizedBox();
          }),
        ));

        await controller.showPostRaceFlow(ctx!, true);
        await controller.showPostRaceFlow(ctx!, true);

        expect(capturedIndices[0], 0); // first call: starts at default 0
        expect(capturedIndices[1], 1); // second call: resumes at persisted 1
      });

      testWidgets('forwards dismissible as showProgressIndicator',
          (tester) async {
        final captured = <bool>[];

        Future<bool> fakeShowFlow({
          required BuildContext context,
          required List<FlowStep> steps,
          bool showProgressIndicator = true,
          int initialIndex = 0,
          StepChangedCallback? onStepChanged,
          void Function(int lastIndex)? onDismiss,
        }) async {
          captured.add(showProgressIndicator);
          onDismiss?.call(0);
          return false;
        }

        final controller = _buildController(
          mockMasterRace,
          showFlowFn: fakeShowFlow,
          loadResultsController: mockLoadResultsController,
        );

        BuildContext? ctx;
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (context) {
            ctx = context;
            return const SizedBox();
          }),
        ));

        await controller.showPostRaceFlow(ctx!, true);
        await controller.showPostRaceFlow(ctx!, false);

        expect(captured[0], isTrue);
        expect(captured[1], isFalse);
      });

      testWidgets('passes the correct steps in order', (tester) async {
        List<FlowStep>? capturedSteps;

        Future<bool> fakeShowFlow({
          required BuildContext context,
          required List<FlowStep> steps,
          bool showProgressIndicator = true,
          int initialIndex = 0,
          StepChangedCallback? onStepChanged,
          void Function(int lastIndex)? onDismiss,
        }) async {
          capturedSteps = steps;
          onDismiss?.call(0);
          return false;
        }

        final controller = _buildController(
          mockMasterRace,
          showFlowFn: fakeShowFlow,
          loadResultsController: mockLoadResultsController,
        );

        BuildContext? ctx;
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (context) {
            ctx = context;
            return const SizedBox();
          }),
        ));

        await controller.showPostRaceFlow(ctx!, false);

        expect(capturedSteps, isNotNull);
        expect(capturedSteps!.length, 2);
        expect(capturedSteps![0], isA<ReconnectStep>());
        expect(capturedSteps![1], isA<LoadResultsStep>());
      });
    });
  });
}
