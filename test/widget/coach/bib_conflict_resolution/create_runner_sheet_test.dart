import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/bib_conflict_resolution/widgets/create_runner_sheet.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';

// Adding a runner happens with the keyboard up, which leaves the sheet less
// than half the screen. Everything in it has to stay reachable.

void main() {
  for (final (name, size, keyboard) in const [
    ('iPhone 13 Pro', Size(390, 844), 336.0),
    ('iPhone SE', Size(375, 667), 260.0),
  ]) {
    testWidgets('fits above the keyboard on an $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => sheet(
                  context: context,
                  title: 'Add New Runner',
                  body: CreateRunnerSheet(
                    allKnownBibs: const {'101'},
                    teams: const ['Eagles', 'Hawks', 'Owls'],
                    autoBib: '9217',
                    onCreated: (_, _, _, _) {},
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // A RenderFlex overflow fails the test.
      expect(find.text('Runner name'), findsOneWidget);
    });
  }
}
