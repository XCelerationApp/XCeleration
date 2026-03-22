import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/controller/bib_recorder_v2_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/swipe_bib_row_widget.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/bib_entry.dart';

import 'swipe_bib_row_widget_test.mocks.dart';

@GenerateMocks([BibRecorderV2Controller])
void main() {
  late MockBibRecorderV2Controller mockController;

  setUp(() {
    mockController = MockBibRecorderV2Controller();
    when(mockController.flagFor(any, excludeId: anyNamed('excludeId')))
        .thenReturn(null);
    when(mockController.runnerFor(any)).thenReturn(null);
  });

  Widget wrap(BibEntry entry) => MaterialApp(
        home: Scaffold(
          body: SwipeBibRowWidget(
            entry: entry,
            position: 1,
            controller: mockController,
          ),
        ),
      );

  group('SwipeBibRowWidget', () {
    group('uncorrected entry', () {
      testWidgets('renders the original bib number', (tester) async {
        await tester.pumpWidget(wrap(const BibEntry(id: 1, bib: 101)));
        await tester.pump();

        expect(find.text('101'), findsOneWidget);
        expect(find.text('Corrected'), findsNothing);
      });

      testWidgets('shows duplicate flag when flagFor returns duplicate',
          (tester) async {
        when(mockController.flagFor(101, excludeId: 1)).thenReturn('duplicate');

        await tester.pumpWidget(wrap(const BibEntry(id: 1, bib: 101)));
        await tester.pump();

        expect(find.textContaining('Duplicate'), findsOneWidget);
        expect(find.text('Corrected'), findsNothing);
      });

      testWidgets('shows unknown flag when flagFor returns unknown',
          (tester) async {
        when(mockController.flagFor(101, excludeId: 1)).thenReturn('unknown');

        await tester.pumpWidget(wrap(const BibEntry(id: 1, bib: 101)));
        await tester.pump();

        expect(find.textContaining('Not in roster'), findsOneWidget);
        expect(find.text('Corrected'), findsNothing);
      });
    });

    group('corrected entry', () {
      testWidgets('shows corrected bib as primary value', (tester) async {
        await tester.pumpWidget(
            wrap(const BibEntry(id: 1, bib: 101, correctedTo: 114)));
        await tester.pump();

        expect(find.text('114'), findsOneWidget);
      });

      testWidgets('shows original bib with strikethrough decoration',
          (tester) async {
        await tester.pumpWidget(
            wrap(const BibEntry(id: 1, bib: 101, correctedTo: 114)));
        await tester.pump();

        expect(find.text('101'), findsOneWidget);

        final struckText = tester.widget<Text>(find.text('101'));
        expect(struckText.style?.decoration, TextDecoration.lineThrough);
      });

      testWidgets('shows Corrected badge', (tester) async {
        await tester.pumpWidget(
            wrap(const BibEntry(id: 1, bib: 101, correctedTo: 114)));
        await tester.pump();

        expect(find.text('Corrected'), findsOneWidget);
      });

      testWidgets('hides duplicate flag chip', (tester) async {
        when(mockController.flagFor(101, excludeId: 1)).thenReturn('duplicate');

        await tester.pumpWidget(
            wrap(const BibEntry(id: 1, bib: 101, correctedTo: 114)));
        await tester.pump();

        expect(find.textContaining('Duplicate'), findsNothing);
        expect(find.text('Corrected'), findsOneWidget);
      });

      testWidgets('hides unknown flag chip', (tester) async {
        when(mockController.flagFor(101, excludeId: 1)).thenReturn('unknown');

        await tester.pumpWidget(
            wrap(const BibEntry(id: 1, bib: 101, correctedTo: 114)));
        await tester.pump();

        expect(find.textContaining('Not in roster'), findsNothing);
        expect(find.text('Corrected'), findsOneWidget);
      });
    });
  });
}
