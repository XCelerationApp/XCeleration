import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/components/status_badge.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/shared/models/database/race.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  group('StatusBadge', () {
    group('labels', () {
      final cases = {
        Race.FLOW_SETUP: 'Setting Up',
        Race.FLOW_SETUP_COMPLETED: 'Ready to Send',
        Race.FLOW_PRE_RACE: 'Sending',
        Race.FLOW_PRE_RACE_COMPLETED: 'Race Ready',
        Race.FLOW_POST_RACE: 'Collecting Results',
        Race.FLOW_FINISHED: 'Race Complete',
      };

      for (final entry in cases.entries) {
        testWidgets('shows "${entry.value}" for ${entry.key}', (tester) async {
          await tester.pumpWidget(
              _wrap(StatusBadge(flowState: entry.key)));
          expect(find.text(entry.value), findsOneWidget);
        });
      }

      testWidgets('treats an unrecognised flow state as setup',
          (tester) async {
        await tester.pumpWidget(_wrap(const StatusBadge(flowState: 'bogus')));
        expect(find.text('Setting Up'), findsOneWidget);
      });
    });

    group('colors', () {
      testWidgets('setup state uses statusSetup color', (tester) async {
        await tester.pumpWidget(
            _wrap(const StatusBadge(flowState: Race.FLOW_SETUP)));
        await tester.pump();

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(StatusBadge),
            matching: find.byType(Container),
          ).first,
        );
        final decoration = container.decoration as BoxDecoration;
        expect(
          decoration.color,
          AppColors.statusSetup.withValues(alpha: 0.10),
        );
      });

      testWidgets('finished state uses statusFinished color', (tester) async {
        await tester.pumpWidget(
            _wrap(const StatusBadge(flowState: Race.FLOW_FINISHED)));
        await tester.pump();

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(StatusBadge),
            matching: find.byType(Container),
          ).first,
        );
        final decoration = container.decoration as BoxDecoration;
        expect(
          decoration.color,
          AppColors.statusFinished.withValues(alpha: 0.10),
        );
      });
    });

    testWidgets('renders for every known flow state without error',
        (tester) async {
      for (final state in Race.FLOW_SEQUENCE) {
        await tester.pumpWidget(_wrap(StatusBadge(flowState: state)));
        expect(find.byType(StatusBadge), findsOneWidget);
      }
    });
  });
}
