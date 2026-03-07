import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/flows/widgets/flow_indicator.dart';

Widget _buildApp(EnhancedFlowIndicator widget) {
  return MaterialApp(home: Scaffold(body: widget));
}

void main() {
  group('EnhancedFlowIndicator', () {
    group('back button', () {
      testWidgets('is present when onBack is not null', (tester) async {
        await tester.pumpWidget(_buildApp(
          EnhancedFlowIndicator(
            totalSteps: 3,
            currentStep: 0,
            onBack: () {},
          ),
        ));

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      });

      testWidgets('is absent when onBack is null', (tester) async {
        await tester.pumpWidget(_buildApp(
          const EnhancedFlowIndicator(
            totalSteps: 3,
            currentStep: 0,
          ),
        ));

        expect(find.byIcon(Icons.arrow_back), findsNothing);
      });

      testWidgets('tapping invokes onBack', (tester) async {
        bool tapped = false;

        await tester.pumpWidget(_buildApp(
          EnhancedFlowIndicator(
            totalSteps: 3,
            currentStep: 0,
            onBack: () => tapped = true,
          ),
        ));

        await tester.tap(find.byIcon(Icons.arrow_back));

        expect(tapped, isTrue);
      });
    });

    group('step segments', () {
      testWidgets('renders totalSteps segments', (tester) async {
        const totalSteps = 4;

        await tester.pumpWidget(_buildApp(
          const EnhancedFlowIndicator(
            totalSteps: totalSteps,
            currentStep: 0,
          ),
        ));

        final segments = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxHeight == 5.0,
        );
        expect(segments, findsNWidgets(totalSteps));
      });
    });
  });
}
