import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/race_screen/widgets/race_steps_bar.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/shared/models/database/race.dart';
import 'package:xceleration/shared/models/race_stage.dart';

// The race header shows the three steps of a race and which one the coach is
// on. It has to fit beside the action button on the narrowest phone.

void main() {
  for (final state in Race.FLOW_SEQUENCE.take(5)) {
    testWidgets('fits on a small phone at $state', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
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
      ));

      // A RenderFlex overflow fails the test.
      for (final name in RaceStage.steps) {
        expect(find.text(name), findsOneWidget);
      }
    });
  }
}
