import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/shared/widgets/race_day_controls.dart';
import 'package:xceleration/core/theme/app_colors.dart';

Widget _wrap(Widget child, {double textScale = 1}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('BigActionButton', () {
    testWidgets('acts as the finger lands with onTapDown', (tester) async {
      var presses = 0;
      await tester.pumpWidget(_wrap(BigActionButton(
        label: 'Log Finish',
        color: AppColors.primaryColor,
        onTapDown: () => presses++,
      )));

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Log Finish')));
      await tester.pump();
      expect(presses, 1);
      await gesture.up();
      expect(presses, 1);
    });

    testWidgets('waits for the finger to lift with onPressed', (tester) async {
      var presses = 0;
      await tester.pumpWidget(_wrap(BigActionButton(
        label: 'Add Bib',
        color: AppColors.primaryColor,
        onPressed: () => presses++,
      )));

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Add Bib')));
      await tester.pump();
      expect(presses, 0);
      await gesture.up();
      expect(presses, 1);
    });

    testWidgets('does nothing when it has no action', (tester) async {
      await tester.pumpWidget(_wrap(const BigActionButton(
        label: 'Add Bib',
        color: AppColors.primaryColor,
      )));

      await tester.tap(find.text('Add Bib'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('grows to fit a large text size', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(
        BigActionButton(
          label: 'Start Recording',
          sublabel: 'Opens the keypad for the first runner',
          icon: Icons.play_arrow,
          color: AppColors.primaryColor,
          onPressed: () {},
        ),
        textScale: 2,
      ));

      expect(tester.takeException(), isNull);
    });
  });

  group('RaceDayStatusBar', () {
    testWidgets('shows Stop only while the race runs', (tester) async {
      var stopped = false;
      await tester.pumpWidget(_wrap(RaceDayStatusBar(
        status: 'Recording',
        color: AppColors.primaryColor,
        count: '3 bibs',
        onStop: () => stopped = true,
      )));

      expect(find.text('Recording'), findsOneWidget);
      expect(find.text('· 3 bibs'), findsOneWidget);
      await tester.tap(find.text('Stop'));
      expect(stopped, isTrue);

      await tester.pumpWidget(_wrap(const RaceDayStatusBar(
        status: 'Stopped',
        color: AppColors.mediumColor,
        count: '3 bibs',
      )));
      expect(find.text('Stop'), findsNothing);
    });
  });
}
