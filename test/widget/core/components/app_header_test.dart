import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/components/app_header.dart';
import 'package:xceleration/core/services/tutorial_manager.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

Widget _wrap({
  required String title,
  required Role role,
  required TutorialManager tutorialManager,
  required VoidCallback onRoleTap,
  required VoidCallback onSettingsTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: AppHeader(
        title: title,
        currentRole: role,
        tutorialManager: tutorialManager,
        onRoleTap: onRoleTap,
        onSettingsTap: onSettingsTap,
      ),
    ),
  );
}

void main() {
  late TutorialManager tutorialManager;

  setUp(() {
    tutorialManager = TutorialManager();
  });

  tearDown(() {
    tutorialManager.dispose();
  });

  group('AppHeader', () {
    group('title rendering', () {
      testWidgets('displays the provided title text', (tester) async {
        await tester.pumpWidget(_wrap(
          title: 'My Races',
          role: Role.coach,
          tutorialManager: tutorialManager,
          onRoleTap: () {},
          onSettingsTap: () {},
        ));

        expect(find.text('My Races'), findsOneWidget);
      });

      testWidgets('renders role-specific title correctly', (tester) async {
        await tester.pumpWidget(_wrap(
          title: 'Timer',
          role: Role.timer,
          tutorialManager: tutorialManager,
          onRoleTap: () {},
          onSettingsTap: () {},
        ));

        expect(find.text('Timer'), findsOneWidget);
      });
    });

    group('onRoleTap callback', () {
      testWidgets('fires when role button is tapped', (tester) async {
        var tapped = false;

        await tester.pumpWidget(_wrap(
          title: 'Races',
          role: Role.coach,
          tutorialManager: tutorialManager,
          onRoleTap: () => tapped = true,
          onSettingsTap: () {},
        ));

        await tester.tap(find.byIcon(Icons.person_outline));
        expect(tapped, isTrue);
      });
    });

    group('onSettingsTap callback', () {
      testWidgets('fires when settings button is tapped', (tester) async {
        var tapped = false;

        await tester.pumpWidget(_wrap(
          title: 'Races',
          role: Role.coach,
          tutorialManager: tutorialManager,
          onRoleTap: () {},
          onSettingsTap: () => tapped = true,
        ));

        await tester.tap(find.byIcon(Icons.settings_outlined));
        expect(tapped, isTrue);
      });
    });

    group('icon buttons', () {
      testWidgets('renders info, role, and settings icon buttons',
          (tester) async {
        await tester.pumpWidget(_wrap(
          title: 'Races',
          role: Role.coach,
          tutorialManager: tutorialManager,
          onRoleTap: () {},
          onSettingsTap: () {},
        ));

        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        expect(find.byIcon(Icons.person_outline), findsOneWidget);
        expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      });
    });
  });
}
