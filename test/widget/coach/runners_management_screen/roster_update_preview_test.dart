import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/runners_management_screen/services/roster_update.dart';
import 'package:xceleration/coach/runners_management_screen/widgets/roster_update_preview.dart';
import 'package:xceleration/shared/models/database/runner.dart';

// Before a team is updated from a spreadsheet, the coach sees who is new,
// whose details change, and who comes off the team.

void main() {
  const bo = Runner(runnerId: 2, name: 'Bo Park', bibNumber: '102', grade: 11);
  const cy = Runner(runnerId: 3, name: 'Cy Diaz', bibNumber: '103', grade: 12);
  final plan = RosterUpdatePlan(
    added: const [
      {'name': 'Di Fox', 'bib': '104', 'grade': 9},
    ],
    changed: [RunnerChange(before: bo, after: bo.copyWith(grade: 12))],
    removed: const [cy],
  );

  Future<bool?> open(WidgetTester tester, {bool confirm = false}) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      Scaffold(body: RosterUpdatePreview(plan: plan)),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    if (confirm) {
      await tester.tap(find.text('Update Team'));
      await tester.pumpAndSettle();
    }
    return result;
  }

  testWidgets('lists new, changed and removed runners', (tester) async {
    await open(tester);

    expect(find.text('New (1)'), findsOneWidget);
    expect(find.textContaining('Di Fox'), findsOneWidget);
    expect(find.text('Changed (1)'), findsOneWidget);
    expect(find.text('Bo Park: Grade 11 → 12'), findsOneWidget);
    expect(find.text('Not on the sheet (1)'), findsOneWidget);
    expect(find.textContaining('Cy Diaz'), findsOneWidget);
  });

  testWidgets('Update Team confirms', (tester) async {
    expect(await open(tester, confirm: true), isTrue);
  });
}
