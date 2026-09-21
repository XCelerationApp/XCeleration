import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/verifier_entry.dart';
import 'package:xceleration/assistant/finish_line_roles/verifier/controller/verifier_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/verifier/widgets/verifier_entry_card.dart';
import 'package:xceleration/assistant/finish_line_roles/verifier/widgets/verifier_stats_bar.dart';

import 'verifier_screen_test.mocks.dart';

@GenerateMocks([VerifierController])
void main() {
  late MockVerifierController mockController;

  setUp(() {
    mockController = MockVerifierController();
    // Default stubs used by VerifierStatsBar and the card.
    when(mockController.pending).thenReturn(0);
    when(mockController.confirmed).thenReturn(0);
    when(mockController.wrong).thenReturn(0);
    when(mockController.skipped).thenReturn(0);
    when(mockController.addListener(any)).thenReturn(null);
    when(mockController.removeListener(any)).thenReturn(null);
  });

  Widget wrapCard(VerifierEntry entry) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VerifierEntryCard(
              entry: entry,
              controller: mockController,
            ),
          ),
        ),
      );

  Widget wrapStatsBar() => MaterialApp(
        home: Scaffold(
          body: VerifierStatsBar(controller: mockController),
        ),
      );

  group('VerifierEntryCard', () {
    testWidgets('pending entry renders bib number and position', (tester) async {
      final entry = VerifierEntry(id: 1, position: 3, bib: 205);

      await tester.pumpWidget(wrapCard(entry));
      await tester.pump();

      expect(find.text('#205'), findsOneWidget);
      // Position ordinal '3rd'
      expect(find.textContaining('3'), findsWidgets);
    });

    testWidgets('pending entry shows team abbreviation when present',
        (tester) async {
      final entry = VerifierEntry(
        id: 1,
        position: 1,
        bib: 101,
        runnerName: 'Alice Smith',
        teamAbbreviation: 'NCC',
      );

      await tester.pumpWidget(wrapCard(entry));
      await tester.pump();

      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('NCC'), findsOneWidget);
    });

    testWidgets('shows DUPLICATE banner for duplicate-flagged entry',
        (tester) async {
      final entry = VerifierEntry(
        id: 1,
        position: 2,
        bib: 107,
        flag: BibFlag.duplicate,
      );

      await tester.pumpWidget(wrapCard(entry));
      await tester.pump();

      expect(find.textContaining('DUPLICATE'), findsOneWidget);
    });

    testWidgets('shows UNKNOWN BIB banner for unknown-flagged entry',
        (tester) async {
      final entry = VerifierEntry(
        id: 1,
        position: 3,
        bib: 999,
        flag: BibFlag.unknown,
      );

      await tester.pumpWidget(wrapCard(entry));
      await tester.pump();

      expect(find.text('UNKNOWN BIB'), findsOneWidget);
    });

    testWidgets('shows action buttons for pending entry', (tester) async {
      final entry = VerifierEntry(id: 1, position: 1, bib: 101);

      await tester.pumpWidget(wrapCard(entry));
      await tester.pump();

      // Pending entry shows Wrong / Skip / Correct buttons.
      expect(find.text('Wrong'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Correct'), findsOneWidget);
    });

    testWidgets('shows Undo button for acted entry within 3-second window',
        (tester) async {
      // An acted entry (e.g. verified but not yet committed) still shows in
      // the entries list with its acted status.
      final entry = VerifierEntry(
        id: 1,
        position: 1,
        bib: 101,
        status: VerificationStatus.verified,
      );

      await tester.pumpWidget(wrapCard(entry));
      await tester.pump();

      expect(find.text('Undo'), findsOneWidget);
      expect(find.text('Wrong'), findsNothing);
    });

    testWidgets('shows Sent to Fixer label for flagged acted entry',
        (tester) async {
      final entry = VerifierEntry(
        id: 1,
        position: 1,
        bib: 101,
        status: VerificationStatus.flagged,
      );

      await tester.pumpWidget(wrapCard(entry));
      await tester.pump();

      expect(find.text('Sent to Fixer'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });
  });

  group('VerifierStatsBar', () {
    testWidgets('displays pending count', (tester) async {
      when(mockController.pending).thenReturn(5);

      await tester.pumpWidget(wrapStatsBar());
      await tester.pump();

      expect(find.text('5'), findsWidgets);
    });

    testWidgets('displays confirmed count', (tester) async {
      when(mockController.confirmed).thenReturn(3);

      await tester.pumpWidget(wrapStatsBar());
      await tester.pump();

      expect(find.text('3'), findsWidgets);
    });
  });
}
