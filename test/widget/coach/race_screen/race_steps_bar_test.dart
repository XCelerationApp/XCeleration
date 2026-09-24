import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/race_screen/widgets/race_steps_bar.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/shared/models/database/race.dart';
import 'package:xceleration/shared/models/race_stage.dart';

// The race header shows how far along the race is and names the step the
// coach is on. It has to fit the narrowest phone, even at a large text size.

Widget _bar(String state, {double textScale = 1}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            // The full width of the header on the narrowest phone.
            child: SizedBox(
              width: 288,
              child: RaceStepsBar(
                  stage: RaceStage.of(state), color: AppColors.primaryColor),
            ),
          ),
        ),
      ),
    );

void main() {
  for (final state in Race.FLOW_SEQUENCE.take(5)) {
    testWidgets('names the step at $state', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_bar(state));

      final stage = RaceStage.of(state);
      expect(
        find.textContaining('Step ${stage.step} of 3'),
        findsOneWidget,
      );
      expect(find.textContaining(stage.label), findsOneWidget);
    });

    testWidgets('fits a small phone at a large text size at $state',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // A RenderFlex overflow fails the test.
      await tester.pumpWidget(_bar(state, textScale: 2));
      expect(tester.takeException(), isNull);
    });
  }
}
