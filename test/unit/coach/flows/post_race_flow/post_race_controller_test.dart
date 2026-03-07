import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/flows/PostRaceFlow/controller/post_race_controller.dart';
import 'package:xceleration/coach/flows/PostRaceFlow/steps/load_results/load_results_step.dart';
import 'package:xceleration/coach/flows/PostRaceFlow/steps/reconnect/reconnect_step.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';
import 'package:xceleration/shared/models/database/master_race.dart';

@GenerateMocks([MasterRace])
import 'post_race_controller_test.mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PostRaceController _buildController(
  MockMasterRace mockMasterRace, {
  ShowFlowFn? showFlowFn,
}) {
  return PostRaceController(
    masterRace: mockMasterRace,
    showFlowFn: showFlowFn,
  );
}

void _stubMasterRace(MockMasterRace mockMasterRace) {
  when(mockMasterRace.results).thenAnswer((_) async => []);
}

// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMasterRace mockMasterRace;

  setUp(() {
    mockMasterRace = MockMasterRace();
    _stubMasterRace(mockMasterRace);
  });

  // =========================================================================
  group('PostRaceController', () {
    // -----------------------------------------------------------------------
    group('_initializeSteps', () {
      test('builds two steps in the correct order', () {
        final controller = _buildController(mockMasterRace);

        final steps = controller.buildSteps();

        expect(steps.length, 2);
        expect(steps[0], isA<ReconnectStep>());
        expect(steps[1], isA<LoadResultsStep>());
      });
    });

    // -----------------------------------------------------------------------
    group('_lastStepIndex', () {
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
    });
  });
}
