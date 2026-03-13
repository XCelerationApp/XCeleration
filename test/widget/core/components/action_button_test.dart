import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/components/action_button.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ActionButton', () {
    group('text rendering', () {
      testWidgets('displays the provided text', (tester) async {
        await tester.pumpWidget(
          _wrap(const ActionButton(text: 'Submit')),
        );

        expect(find.text('Submit'), findsOneWidget);
      });
    });

    group('onPressed callback', () {
      testWidgets('fires onPressed when tapped and enabled', (tester) async {
        var pressed = false;

        await tester.pumpWidget(
          _wrap(ActionButton(
            text: 'Go',
            onPressed: () => pressed = true,
          )),
        );

        await tester.tap(find.byType(ActionButton));
        expect(pressed, isTrue);
      });

      testWidgets('does not fire onPressed when disabled', (tester) async {
        var pressed = false;

        await tester.pumpWidget(
          _wrap(ActionButton(
            text: 'Go',
            isEnabled: false,
            onPressed: () => pressed = true,
          )),
        );

        await tester.tap(find.byType(ActionButton));
        expect(pressed, isFalse);
      });
    });

    group('icon', () {
      testWidgets('renders icon when provided', (tester) async {
        await tester.pumpWidget(
          _wrap(const ActionButton(
            text: 'Save',
            icon: Icons.save,
          )),
        );

        expect(find.byIcon(Icons.save), findsOneWidget);
      });

      testWidgets('renders no icon when not provided', (tester) async {
        await tester.pumpWidget(
          _wrap(const ActionButton(text: 'Save')),
        );

        expect(find.byType(Icon), findsNothing);
      });

      testWidgets('places icon before text when iconLeading is true',
          (tester) async {
        await tester.pumpWidget(
          _wrap(const ActionButton(
            text: 'Save',
            icon: Icons.save,
            iconLeading: true,
          )),
        );

        final row = tester.widget<Row>(
          find.descendant(
            of: find.byType(ActionButton),
            matching: find.byType(Row),
          ).first,
        );
        expect(row.children.first, isA<Icon>());
      });

      testWidgets('places icon after text when iconLeading is false',
          (tester) async {
        await tester.pumpWidget(
          _wrap(const ActionButton(
            text: 'Next',
            icon: Icons.arrow_forward,
            iconLeading: false,
          )),
        );

        final row = tester.widget<Row>(
          find.descendant(
            of: find.byType(ActionButton),
            matching: find.byType(Row),
          ).first,
        );
        expect(row.children.last, isA<Icon>());
      });
    });

    group('size variants', () {
      testWidgets('renders small size without error', (tester) async {
        await tester.pumpWidget(
          _wrap(const ActionButton(
            text: 'Small',
            size: ButtonSize.small,
          )),
        );

        expect(find.text('Small'), findsOneWidget);
      });

      testWidgets('renders large size without error', (tester) async {
        await tester.pumpWidget(
          _wrap(const ActionButton(
            text: 'Large',
            size: ButtonSize.large,
          )),
        );

        expect(find.text('Large'), findsOneWidget);
      });

      testWidgets('renders full-width size without error', (tester) async {
        await tester.pumpWidget(
          _wrap(const ActionButton(
            text: 'Full',
            size: ButtonSize.fullWidth,
          )),
        );

        expect(find.text('Full'), findsOneWidget);
      });
    });

    group('primary vs secondary', () {
      testWidgets('renders primary button without error', (tester) async {
        await tester.pumpWidget(
          _wrap(const ActionButton(
            text: 'Primary',
            isPrimary: true,
          )),
        );

        expect(find.text('Primary'), findsOneWidget);
      });

      testWidgets('renders secondary button without error', (tester) async {
        await tester.pumpWidget(
          _wrap(const ActionButton(
            text: 'Secondary',
            isPrimary: false,
          )),
        );

        expect(find.text('Secondary'), findsOneWidget);
      });
    });
  });
}
