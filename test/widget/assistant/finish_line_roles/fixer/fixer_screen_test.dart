import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/controller/fixer_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/widgets/fixer_entry_card.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/widgets/fixer_queue_widgets.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/fixer_entry.dart';

import 'fixer_screen_test.mocks.dart';

@GenerateMocks([FixerController])
void main() {
  late MockFixerController mockController;

  setUp(() {
    mockController = MockFixerController();
    when(mockController.queue).thenReturn([]);
    when(mockController.searchResults).thenReturn([]);
    when(mockController.searchQuery).thenReturn('');
    when(mockController.unresolvedCount).thenReturn(0);
    when(mockController.isInRace).thenReturn(true);
    when(mockController.addListener(any)).thenReturn(null);
    when(mockController.removeListener(any)).thenReturn(null);
  });

  Widget wrapCard(FixerEntry entry) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FixerEntryCard(
              entry: entry,
              controller: mockController,
            ),
          ),
        ),
      );

  Widget wrapStatusPill(int count) => MaterialApp(
        home: Scaffold(
          body: FixerStatusPill(unresolvedCount: count),
        ),
      );

  group('FixerEntryCard', () {
    const unresolvedEntry = FixerEntry(
      id: 1,
      position: 1,
      bib: 107,
      reason: FixReason.verifierFlagged,
    );

    testWidgets('shows bib number for unresolved entry', (tester) async {
      await tester.pumpWidget(wrapCard(unresolvedEntry));
      await tester.pump();

      expect(find.text('#107'), findsOneWidget);
    });

    testWidgets('shows verifierFlagged reason chip', (tester) async {
      await tester.pumpWidget(wrapCard(unresolvedEntry));
      await tester.pump();

      expect(find.textContaining('Flagged by Verifier'), findsOneWidget);
    });

    testWidgets('shows duplicate reason chip', (tester) async {
      const entry = FixerEntry(
        id: 2,
        position: 2,
        bib: 101,
        reason: FixReason.duplicate,
      );

      await tester.pumpWidget(wrapCard(entry));
      await tester.pump();

      expect(find.textContaining('duplicate'), findsOneWidget);
    });

    testWidgets('shows unknown reason chip', (tester) async {
      const entry = FixerEntry(
        id: 3,
        position: 3,
        bib: 999,
        reason: FixReason.unknown,
      );

      await tester.pumpWidget(wrapCard(entry));
      await tester.pump();

      expect(find.textContaining("doesn't match runner"), findsOneWidget);
    });

    testWidgets('resolved entry shows resolved state (no chevron)', (tester) async {
      const resolvedEntry = FixerEntry(
        id: 1,
        position: 1,
        bib: 107,
        reason: FixReason.verifierFlagged,
        isResolved: true,
        correctedBib: 110,
        resolvedName: 'Ryan Smith',
      );

      await tester.pumpWidget(wrapCard(resolvedEntry));
      await tester.pump();

      // Resolved card shows the resolved runner name.
      expect(find.text('Ryan Smith'), findsOneWidget);
      // No chevron on resolved card.
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('resolved entry with bib correction shows "bib corrected" label',
        (tester) async {
      const resolvedEntry = FixerEntry(
        id: 1,
        position: 1,
        bib: 107,
        reason: FixReason.duplicate,
        isResolved: true,
        correctedBib: 110,
        resolvedName: 'Ryan Smith',
      );

      await tester.pumpWidget(wrapCard(resolvedEntry));
      await tester.pump();

      expect(find.textContaining('bib corrected'), findsOneWidget);
    });

    testWidgets('resolved new-runner entry shows "new runner" label',
        (tester) async {
      const resolvedEntry = FixerEntry(
        id: 1,
        position: 1,
        bib: 999,
        reason: FixReason.unknown,
        isResolved: true,
        isNewRunner: true,
        resolvedName: 'Jane Doe',
      );

      await tester.pumpWidget(wrapCard(resolvedEntry));
      await tester.pump();

      expect(find.textContaining('new runner'), findsOneWidget);
    });
  });

  group('FixerStatusPill', () {
    testWidgets('shows count and "need attention" when count > 0', (tester) async {
      await tester.pumpWidget(wrapStatusPill(3));
      await tester.pump();

      expect(find.textContaining('3'), findsOneWidget);
      expect(find.textContaining('need attention'), findsOneWidget);
    });

    testWidgets('shows "All entries resolved" when count is 0', (tester) async {
      await tester.pumpWidget(wrapStatusPill(0));
      await tester.pump();

      expect(find.textContaining('All entries resolved'), findsOneWidget);
    });

    testWidgets('uses singular "entry" for count of 1', (tester) async {
      await tester.pumpWidget(wrapStatusPill(1));
      await tester.pump();

      expect(find.textContaining('1 entry'), findsOneWidget);
    });
  });

  group('FixerEmptyState', () {
    testWidgets('shows no-conflicts message', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: FixerEmptyState()),
      ));
      await tester.pump();

      expect(find.text('No conflicts to resolve'), findsOneWidget);
    });
  });
}
