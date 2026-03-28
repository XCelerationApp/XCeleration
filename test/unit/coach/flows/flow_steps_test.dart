import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/flows/controller/flow_controller.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';
import 'package:xceleration/coach/flows/pre_race_flow/steps/review_runners/review_runners_step.dart';
import 'package:xceleration/shared/models/database/master_race.dart';

FlowStep _step({
  bool Function()? canProceed,
  Future<void> Function()? onNext,
  VoidCallback? onBack,
}) =>
    FlowStep(
      title: 'Step',
      description: 'Description',
      content: const SizedBox(),
      canProceed: canProceed,
      onNext: onNext,
      onBack: onBack,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // FlowStep
  // ===========================================================================
  group('FlowStep', () {
    group('notifyContentChanged', () {
      test('emits an event on onContentChange', () async {
        final step = _step();
        bool emitted = false;
        step.onContentChange.listen((_) => emitted = true);
        step.notifyContentChanged();
        await Future<void>.delayed(Duration.zero);
        expect(emitted, isTrue);
        step.dispose();
      });
    });

    group('onContentChange', () {
      test('supports multiple listeners (broadcast stream)', () async {
        final step = _step();
        int count = 0;
        step.onContentChange.listen((_) => count++);
        step.onContentChange.listen((_) => count++);
        step.notifyContentChanged();
        await Future<void>.delayed(Duration.zero);
        expect(count, 2);
        step.dispose();
      });
    });

    group('dispose', () {
      test('closes the stream so notifyContentChanged throws StateError', () {
        final step = _step();
        step.dispose();
        expect(step.notifyContentChanged, throwsStateError);
      });
    });
  });

  // ===========================================================================
  // ReviewRunnersStep
  // ===========================================================================
  group('ReviewRunnersStep', () {
    late MasterRace masterRace;

    setUp(() {
      masterRace = MasterRace.getInstance(1);
    });

    tearDown(() {
      MasterRace.clearInstance(1);
    });

    ReviewRunnersStep buildStep({
      required Future<bool> Function(MasterRace) checkMinimumRunners,
    }) {
      return ReviewRunnersStep(
        masterRace: masterRace,
        onNext: () async {},
        checkMinimumRunners: checkMinimumRunners,
      );
    }

    group('seedInitialProceed', () {
      test('sets canProceed to true when checker returns true', () async {
        final step = buildStep(checkMinimumRunners: (_) async => true);
        await step.seedInitialProceed();

        expect(step.canProceed(), isTrue);
        step.dispose();
      });

      test('sets canProceed to false when checker returns false', () async {
        final step = buildStep(checkMinimumRunners: (_) async => false);
        await step.seedInitialProceed();

        expect(step.canProceed(), isFalse);
        step.dispose();
      });
    });

    group('checkRunners', () {
      test('notifies content changed when canProceed value changes', () async {
        var returnValue = false;
        final step =
            buildStep(checkMinimumRunners: (_) async => returnValue);

        await Future.microtask(() {});

        final events = <void>[];
        step.onContentChange.listen((_) => events.add(null));

        returnValue = true;
        await step.checkRunners();
        await Future.microtask(() {});

        expect(events, hasLength(1));
        step.dispose();
      });

      test('does not notify when canProceed value is unchanged', () async {
        final step = buildStep(checkMinimumRunners: (_) async => true);

        await step.seedInitialProceed();
        await Future.microtask(() {});

        final events = <void>[];
        step.onContentChange.listen((_) => events.add(null));

        await step.checkRunners();

        expect(events, isEmpty);
        step.dispose();
      });
    });
  });

  // ===========================================================================
  // FlowController
  // ===========================================================================
  group('FlowController', () {
    group('canGoBack', () {
      test('is false at index 0', () {
        final controller = FlowController([_step(), _step()]);
        expect(controller.canGoBack, isFalse);
        controller.dispose();
      });

      test('is true after advancing to index 1', () async {
        final controller = FlowController([_step(), _step()]);
        await controller.goToNext();
        expect(controller.canGoBack, isTrue);
        controller.dispose();
      });
    });

    group('isLastStep', () {
      test('is false when not at final index', () {
        final controller = FlowController([_step(), _step()]);
        expect(controller.isLastStep, isFalse);
        controller.dispose();
      });

      test('is true at final index', () async {
        final controller = FlowController([_step(), _step()]);
        await controller.goToNext();
        expect(controller.isLastStep, isTrue);
        controller.dispose();
      });
    });

    group('canProceed', () {
      test('is true when step has no canProceed predicate', () {
        final controller = FlowController([_step()]);
        expect(controller.canProceed, isTrue);
        controller.dispose();
      });

      test('returns true when predicate returns true', () {
        final controller = FlowController([_step(canProceed: () => true)]);
        expect(controller.canProceed, isTrue);
        controller.dispose();
      });

      test('returns false when predicate returns false', () {
        final controller = FlowController([_step(canProceed: () => false)]);
        expect(controller.canProceed, isFalse);
        controller.dispose();
      });
    });

    group('goToNext', () {
      test('increments currentIndex', () async {
        final controller = FlowController([_step(), _step()]);
        await controller.goToNext();
        expect(controller.currentIndex, 1);
        controller.dispose();
      });

      test('calls onNext callback of current step', () async {
        bool called = false;
        final controller = FlowController([
          _step(onNext: () async { called = true; }),
          _step(),
        ]);
        await controller.goToNext();
        expect(called, isTrue);
        controller.dispose();
      });

      test('notifies listeners', () async {
        final controller = FlowController([_step(), _step()]);
        int notifyCount = 0;
        controller.addListener(() => notifyCount++);
        await controller.goToNext();
        expect(notifyCount, greaterThan(0));
        controller.dispose();
      });

      test('calls onStepChanged callback with new index', () async {
        int? reportedIndex;
        final controller = FlowController(
          [_step(), _step()],
          onStepChanged: (i) => reportedIndex = i,
        );
        await controller.goToNext();
        expect(reportedIndex, 1);
        controller.dispose();
      });
    });

    group('goBack', () {
      test('decrements currentIndex when canGoBack', () async {
        final controller = FlowController([_step(), _step()]);
        await controller.goToNext();
        controller.goBack();
        expect(controller.currentIndex, 0);
        controller.dispose();
      });

      test('calls onBack callback of current step', () async {
        bool called = false;
        final controller = FlowController([
          _step(),
          _step(onBack: () { called = true; }),
        ]);
        await controller.goToNext();
        controller.goBack();
        expect(called, isTrue);
        controller.dispose();
      });

      test('notifies listeners', () async {
        final controller = FlowController([_step(), _step()]);
        await controller.goToNext();
        int notifyCount = 0;
        controller.addListener(() => notifyCount++);
        controller.goBack();
        expect(notifyCount, greaterThan(0));
        controller.dispose();
      });

      test('calls onStepChanged with new index', () async {
        int? reportedIndex;
        final controller = FlowController(
          [_step(), _step()],
          onStepChanged: (i) => reportedIndex = i,
        );
        await controller.goToNext();
        reportedIndex = null;
        controller.goBack();
        expect(reportedIndex, 0);
        controller.dispose();
      });

      test('is a no-op when at index 0', () {
        final controller = FlowController([_step(), _step()]);
        int notifyCount = 0;
        controller.addListener(() => notifyCount++);
        controller.goBack();
        expect(controller.currentIndex, 0);
        expect(notifyCount, 0);
        controller.dispose();
      });
    });

    group('content change subscription', () {
      test('notifies listeners when current step emits a content change',
          () async {
        final step = _step();
        final controller = FlowController([step]);
        int notifyCount = 0;
        controller.addListener(() => notifyCount++);
        step.notifyContentChanged();
        await Future<void>.delayed(Duration.zero);
        expect(notifyCount, greaterThan(0));
        controller.dispose();
      });

      test('subscribes to new step after goToNext', () async {
        final step1 = _step();
        final step2 = _step();
        final controller = FlowController([step1, step2]);
        await controller.goToNext();

        int notifyCount = 0;
        controller.addListener(() => notifyCount++);

        step2.notifyContentChanged();
        await Future<void>.delayed(Duration.zero);
        expect(notifyCount, greaterThan(0));

        notifyCount = 0;
        step1.notifyContentChanged();
        await Future<void>.delayed(Duration.zero);
        expect(notifyCount, 0);

        controller.dispose();
      });
    });

    group('canGoForward', () {
      test('is true when not on last step and canProceed is true', () {
        final controller = FlowController([_step(), _step()]);
        expect(controller.canGoForward, isTrue);
        controller.dispose();
      });

      test('is false when on last step even if canProceed is true', () async {
        final controller = FlowController([_step(), _step()]);
        await controller.goToNext();
        expect(controller.isLastStep, isTrue);
        expect(controller.canProceed, isTrue);
        expect(controller.canGoForward, isFalse);
        controller.dispose();
      });

      test('is false when canProceed is false even if not on last step', () {
        final controller = FlowController([
          _step(canProceed: () => false),
          _step(),
        ]);
        expect(controller.isLastStep, isFalse);
        expect(controller.canProceed, isFalse);
        expect(controller.canGoForward, isFalse);
        controller.dispose();
      });
    });

    group('initialIndex', () {
      test('controller starts at the given initialIndex', () {
        final controller = FlowController([_step(), _step()], initialIndex: 1);
        expect(controller.currentIndex, 1);
        controller.dispose();
      });
    });

    group('single-step flow', () {
      test('isLastStep is true at construction', () {
        final controller = FlowController([_step()]);
        expect(controller.isLastStep, isTrue);
        controller.dispose();
      });

      test('canGoBack is false at construction', () {
        final controller = FlowController([_step()]);
        expect(controller.canGoBack, isFalse);
        controller.dispose();
      });

      test('canGoForward is false at construction', () {
        final controller = FlowController([_step()]);
        expect(controller.canGoForward, isFalse);
        controller.dispose();
      });
    });

    group('dispose', () {
      test('disposes all steps, closing their stream controllers', () {
        final step1 = _step();
        final step2 = _step();
        final controller = FlowController([step1, step2]);
        controller.dispose();
        expect(step1.notifyContentChanged, throwsStateError);
        expect(step2.notifyContentChanged, throwsStateError);
      });
    });
  });
}
