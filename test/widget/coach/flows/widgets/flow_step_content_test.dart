import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/flows/widgets/flow_step_content.dart';

Widget _buildApp({
  required String title,
  required String description,
  required Widget content,
  required int currentStep,
  required int totalSteps,
}) {
  return MaterialApp(
    home: Scaffold(
      body: FlowStepContent(
        title: title,
        description: description,
        content: content,
        currentStep: currentStep,
        totalSteps: totalSteps,
      ),
    ),
  );
}

void main() {
  group('FlowStepContent', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(_buildApp(
        title: 'Test Title',
        description: 'A description',
        content: const SizedBox(),
        currentStep: 0,
        totalSteps: 3,
      ));

      expect(find.text('Test Title'), findsOneWidget);
    });

    testWidgets('renders description text', (tester) async {
      await tester.pumpWidget(_buildApp(
        title: 'Title',
        description: 'Test Description',
        content: const SizedBox(),
        currentStep: 0,
        totalSteps: 3,
      ));

      expect(find.text('Test Description'), findsOneWidget);
    });

    testWidgets('renders content widget', (tester) async {
      await tester.pumpWidget(_buildApp(
        title: 'Title',
        description: 'Description',
        content: const Text('My Content'),
        currentStep: 0,
        totalSteps: 3,
      ));

      expect(find.text('My Content'), findsOneWidget);
    });

    testWidgets('progress indicator renders totalSteps segments',
        (tester) async {
      const totalSteps = 5;

      await tester.pumpWidget(_buildApp(
        title: 'Title',
        description: 'Description',
        content: const SizedBox(),
        currentStep: 0,
        totalSteps: totalSteps,
      ));

      final segments = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxHeight == 4.0,
      );
      expect(segments, findsNWidgets(totalSteps));
    });
  });
}
