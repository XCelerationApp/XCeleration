import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/flows/controller/flow_controller.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';
import 'package:xceleration/coach/flows/widgets/flow_indicator.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FlowStep _step(String title, {bool Function()? canProceed}) {
  return FlowStep(
    title: title,
    description: 'Description for $title',
    content: const SizedBox(),
    canProceed: canProceed,
  );
}

Widget _buildApp(
  List<FlowStep> steps, {
  bool showProgressIndicator = true,
  int initialIndex = 0,
  StepChangedCallback? onStepChanged,
  void Function(int)? onDismiss,
  void Function(Future<bool>)? captureResult,
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    home: Scaffold(
      body: Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () {
            final future = showFlow(
              context: context,
              steps: steps,
              showProgressIndicator: showProgressIndicator,
              initialIndex: initialIndex,
              onStepChanged: onStepChanged,
              onDismiss: onDismiss,
            );
            captureResult?.call(future);
          },
          child: const Text('Open'),
        );
      }),
    ),
  );
}

Future<void> _openFlow(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------

void main() {
  group('showFlow', () {
    testWidgets('shows EnhancedFlowIndicator when showProgressIndicator is true',
        (tester) async {
      await tester.pumpWidget(_buildApp(
        [_step('Step 1')],
        showProgressIndicator: true,
      ));

      await _openFlow(tester);

      expect(find.byType(EnhancedFlowIndicator), findsOneWidget);
    });

    testWidgets(
        'hides EnhancedFlowIndicator when showProgressIndicator is false',
        (tester) async {
      await tester.pumpWidget(_buildApp(
        [_step('Step 1')],
        showProgressIndicator: false,
      ));

      await _openFlow(tester);

      expect(find.byType(EnhancedFlowIndicator), findsNothing);
    });

    testWidgets('Next button is disabled when canProceed returns false',
        (tester) async {
      await tester.pumpWidget(_buildApp(
        [_step('Step 1', canProceed: () => false)],
      ));

      await _openFlow(tester);

      final nextButton = tester.widget<ElevatedButton>(
        find
            .ancestor(
              of: find.text('Next'),
              matching: find.byType(ElevatedButton),
            )
            .first,
      );
      expect(nextButton.onPressed, isNull);
    });

    testWidgets(
        'tapping Next on an intermediate step advances to the next step',
        (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(_buildApp(
        [_step('Step One'), _step('Step Two')],
        navigatorKey: navigatorKey,
      ));

      await _openFlow(tester);
      expect(find.text('Step One'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Step Two'), findsOneWidget);

      // Clean up: dismiss the sheet
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'tapping Next on the last step closes the sheet and returns true',
        (tester) async {
      Future<bool>? resultFuture;

      await tester.pumpWidget(_buildApp(
        [_step('Only Step')],
        captureResult: (f) => resultFuture = f,
      ));

      await _openFlow(tester);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(await resultFuture!, isTrue);
    });

    testWidgets('dismissing the sheet without completing returns false',
        (tester) async {
      Future<bool>? resultFuture;
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(_buildApp(
        [_step('Step 1'), _step('Step 2')],
        navigatorKey: navigatorKey,
        captureResult: (f) => resultFuture = f,
      ));

      await _openFlow(tester);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      expect(await resultFuture!, isFalse);
    });

    testWidgets(
        'onDismiss is called with the last visited step index on dismissal',
        (tester) async {
      int? dismissedAt;
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(_buildApp(
        [_step('Step 1'), _step('Step 2')],
        navigatorKey: navigatorKey,
        onDismiss: (index) => dismissedAt = index,
      ));

      await _openFlow(tester);

      // Advance to step 2 (index 1)
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Dismiss at step 2
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      expect(dismissedAt, 1);
    });

    testWidgets('onStepChanged is called with the new index when advancing',
        (tester) async {
      int? changedTo;
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(_buildApp(
        [_step('Step 1'), _step('Step 2')],
        navigatorKey: navigatorKey,
        onStepChanged: (index) => changedTo = index,
      ));

      await _openFlow(tester);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(changedTo, 1);

      // Clean up
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
    });
  });
}
