import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/runners_management_screen/widgets/existing_teams_browser_sheet.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

// Importing teams from earlier races: every team the coach has ever had is
// listed, so they start closed, and a search finds a team or a runner.

const _eagles = Team(teamId: 1, name: 'Eagles', color: Color(0xFF1565C0));
const _owls = Team(teamId: 2, name: 'Owls', color: Color(0xFF2E7D32));

void main() {
  Object? popped;

  Future<void> pump(WidgetTester tester) async {
    popped = null;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async => popped = await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => ExistingTeamsBrowserSheet(
                  raceId: 1,
                  availableTeams: {
                    _eagles: const [
                      Runner(runnerId: 1, name: 'Ann Lee', bibNumber: '101', grade: 10),
                      Runner(runnerId: 2, name: 'Bo Park', bibNumber: '102', grade: 11),
                    ],
                    _owls: const [
                      Runner(runnerId: 3, name: 'Cy Moss', bibNumber: '201', grade: 12),
                    ],
                  },
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
  }

  testWidgets('teams start closed, and open to show their runners',
      (tester) async {
    await pump(tester);

    expect(find.text('Eagles'), findsOneWidget);
    expect(find.text('Owls'), findsOneWidget);
    expect(find.text('Ann Lee'), findsNothing);

    await tester.tap(find.text('Eagles'));
    await tester.pumpAndSettle();
    expect(find.text('Ann Lee'), findsOneWidget);
    expect(find.text('Cy Moss'), findsNothing);
  });

  testWidgets('the checkbox picks the whole team without opening it',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('import_team_1')));
    await tester.pumpAndSettle();

    expect(find.text('Ann Lee'), findsNothing);
    expect(find.text('Import 2 Runners'), findsOneWidget);
  });

  testWidgets('a search finds a runner and opens their team', (tester) async {
    await pump(tester);

    await tester.enterText(
        find.byKey(const ValueKey('import_team_search')), 'moss');
    await tester.pumpAndSettle();

    expect(find.text('Eagles'), findsNothing);
    expect(find.text('Cy Moss'), findsOneWidget);
  });
}
