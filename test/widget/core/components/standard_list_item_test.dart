import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/components/standard_list_item.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  group('StandardListItem', () {
    group('content rendering', () {
      testWidgets('renders title text', (tester) async {
        await tester.pumpWidget(_wrap(
          const StandardListItem(
            leading: Icon(Icons.star),
            title: 'My Title',
          ),
        ));

        expect(find.text('My Title'), findsOneWidget);
      });

      testWidgets('renders subtitle when provided', (tester) async {
        await tester.pumpWidget(_wrap(
          const StandardListItem(
            leading: Icon(Icons.star),
            title: 'Title',
            subtitle: 'Sub',
          ),
        ));

        expect(find.text('Sub'), findsOneWidget);
      });

      testWidgets('omits subtitle when not provided', (tester) async {
        await tester.pumpWidget(_wrap(
          const StandardListItem(
            leading: Icon(Icons.star),
            title: 'Title',
          ),
        ));

        expect(find.text('Sub'), findsNothing);
      });

      testWidgets('renders trailing widget when provided', (tester) async {
        await tester.pumpWidget(_wrap(
          StandardListItem(
            leading: const Icon(Icons.star),
            title: 'Title',
            trailing: const Icon(Icons.chevron_right, key: Key('trailing')),
          ),
        ));

        expect(find.byKey(const Key('trailing')), findsOneWidget);
      });

      testWidgets('omits trailing when not provided', (tester) async {
        await tester.pumpWidget(_wrap(
          const StandardListItem(
            leading: Icon(Icons.star),
            title: 'Title',
          ),
        ));

        expect(find.byIcon(Icons.chevron_right), findsNothing);
      });
    });

    group('onTap', () {
      testWidgets('calls onTap callback when tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(_wrap(
          StandardListItem(
            leading: const Icon(Icons.star),
            title: 'Title',
            onTap: () => tapped = true,
          ),
        ));

        await tester.tap(find.byType(StandardListItem));
        expect(tapped, isTrue);
      });

      testWidgets('does not throw when onTap is null', (tester) async {
        await tester.pumpWidget(_wrap(
          const StandardListItem(
            leading: Icon(Icons.star),
            title: 'Title',
          ),
        ));

        await tester.tap(find.byType(StandardListItem));
        // no exception = pass
      });
    });

    group('isCompact', () {
      testWidgets('renders in compact mode without error', (tester) async {
        await tester.pumpWidget(_wrap(
          const StandardListItem(
            leading: Icon(Icons.star),
            title: 'Title',
            subtitle: 'Sub',
            isCompact: true,
          ),
        ));

        expect(find.text('Title'), findsOneWidget);
        expect(find.text('Sub'), findsOneWidget);
      });
    });
  });
}
