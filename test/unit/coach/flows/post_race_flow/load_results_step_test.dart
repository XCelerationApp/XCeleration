import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/controller/load_results_controller.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/load_results_step.dart';

@GenerateMocks([LoadResultsController])
import 'load_results_step_test.mocks.dart';

// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLoadResultsController mockController;

  void stubController({
    bool resultsLoaded = false,
    bool hasBibConflicts = false,
    bool hasTimingConflicts = false,
  }) {
    when(mockController.resultsLoaded).thenReturn(resultsLoaded);
    when(mockController.hasBibConflicts).thenReturn(hasBibConflicts);
    when(mockController.hasTimingConflicts).thenReturn(hasTimingConflicts);
  }

  setUp(() {
    mockController = MockLoadResultsController();
    when(mockController.addListener(any)).thenReturn(null);
    when(mockController.removeListener(any)).thenReturn(null);
    stubController();
  });

  // =========================================================================
  group('LoadResultsStep', () {
    // -----------------------------------------------------------------------
    group('canProceed', () {
      late LoadResultsStep step;

      setUp(() => step = LoadResultsStep(controller: mockController));
      tearDown(() => step.dispose());

      test('waits for the results to load', () {
        expect(step.canProceed!(), isFalse);
        expect(step.blockedReason!(), contains('Waiting'));
      });

      test('lets Next lead into the conflicts once loaded', () {
        // Next walks the coach through them, so they do not grey it out.
        stubController(resultsLoaded: true, hasBibConflicts: true);

        expect(step.canProceed!(), isTrue);
        expect(step.blockedReason!(), isNull);
      });
    });

    // -----------------------------------------------------------------------
    group('Next', () {
      late LoadResultsStep step;

      setUp(() => step = LoadResultsStep(controller: mockController));
      tearDown(() => step.dispose());

      Future<BuildContext> host(WidgetTester tester) async {
        late BuildContext context;
        await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
          context = c;
          return const SizedBox();
        })));
        return context;
      }

      testWidgets('opens the bib conflicts first', (tester) async {
        final context = await host(tester);
        stubController(resultsLoaded: true, hasBibConflicts: true);
        when(mockController.showBibConflictsSheet(any)).thenAnswer((_) async {
          stubController(resultsLoaded: true);
        });

        await step.beforeNext!(context);

        verify(mockController.showBibConflictsSheet(any)).called(1);
        verifyNever(mockController.showTimingConflictsSheet(any));
      });

      testWidgets('opens the timing conflicts when only those are left',
          (tester) async {
        final context = await host(tester);
        stubController(resultsLoaded: true, hasTimingConflicts: true);
        when(mockController.showTimingConflictsSheet(any))
            .thenAnswer((_) async => stubController(resultsLoaded: true));

        await step.beforeNext!(context);

        verify(mockController.showTimingConflictsSheet(any)).called(1);
      });

      testWidgets('stays on this page while conflicts are left',
          (tester) async {
        final context = await host(tester);
        stubController(resultsLoaded: true, hasTimingConflicts: true);
        when(mockController.showTimingConflictsSheet(any))
            .thenAnswer((_) async {});

        await expectLater(
            step.beforeNext!(context), throwsA(isA<FlowStepBlocked>()));
      });

      testWidgets('moves straight on when there are no conflicts',
          (tester) async {
        final context = await host(tester);
        stubController(resultsLoaded: true);

        await step.beforeNext!(context);

        verifyNever(mockController.showBibConflictsSheet(any));
        verifyNever(mockController.showTimingConflictsSheet(any));
        expect(step.onNext, isNull, reason: 'saving is on the next page');
      });
    });

    // -----------------------------------------------------------------------
    group('content change propagation', () {
      test('notifyContentChanged fires when controller notifies listeners',
          () async {
        VoidCallback? capturedListener;
        when(mockController.addListener(any)).thenAnswer((invocation) {
          capturedListener =
              invocation.positionalArguments.first as VoidCallback;
        });

        final step = LoadResultsStep(controller: mockController);
        final events = <void>[];
        step.onContentChange.listen((_) => events.add(null));

        capturedListener?.call();
        await Future.microtask(() {});

        expect(events, hasLength(1));
        step.dispose();
      });
    });

    // -----------------------------------------------------------------------
    group('dispose', () {
      test('removes listener from controller', () {
        final step = LoadResultsStep(controller: mockController);
        step.dispose();

        verify(mockController.removeListener(any)).called(1);
      });
    });
  });
}
