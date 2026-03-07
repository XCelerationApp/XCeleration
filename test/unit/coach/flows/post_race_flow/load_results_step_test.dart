import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/flows/PostRaceFlow/steps/load_results/controller/load_results_controller.dart';
import 'package:xceleration/coach/flows/PostRaceFlow/steps/load_results/load_results_step.dart';

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

      test('returns true when resultsLoaded is true and no conflicts', () {
        stubController(resultsLoaded: true);

        expect(step.canProceed!(), isTrue);
      });

      test('returns false when resultsLoaded is false', () {
        expect(step.canProceed!(), isFalse);
      });

      test('returns false when hasBibConflicts is true', () {
        stubController(resultsLoaded: true, hasBibConflicts: true);

        expect(step.canProceed!(), isFalse);
      });

      test('returns false when hasTimingConflicts is true', () {
        stubController(resultsLoaded: true, hasTimingConflicts: true);

        expect(step.canProceed!(), isFalse);
      });
    });

    // -----------------------------------------------------------------------
    group('onNext', () {
      late LoadResultsStep step;

      setUp(() => step = LoadResultsStep(controller: mockController));
      tearDown(() => step.dispose());

      test('calls saveCurrentResults when canProceed conditions are met',
          () async {
        stubController(resultsLoaded: true);
        when(mockController.saveCurrentResults()).thenAnswer((_) async {});

        await step.onNext!();

        verify(mockController.saveCurrentResults()).called(1);
      });

      test('skips saveCurrentResults when resultsLoaded is false', () async {
        await step.onNext!();

        verifyNever(mockController.saveCurrentResults());
      });

      test('skips saveCurrentResults when hasBibConflicts is true', () async {
        stubController(resultsLoaded: true, hasBibConflicts: true);

        await step.onNext!();

        verifyNever(mockController.saveCurrentResults());
      });

      test('skips saveCurrentResults when hasTimingConflicts is true',
          () async {
        stubController(resultsLoaded: true, hasTimingConflicts: true);

        await step.onNext!();

        verifyNever(mockController.saveCurrentResults());
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
