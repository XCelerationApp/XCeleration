import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/controller/bib_recorder_v2_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/race_lobby_widget.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/race_mode_widget.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/bib_entry.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';

import 'bib_recorder_v2_screen_test.mocks.dart';

@GenerateMocks([BibRecorderV2Controller])
void main() {
  late MockBibRecorderV2Controller mockController;

  setUp(() {
    mockController = MockBibRecorderV2Controller();
    // Default stubs — screens/widgets read these on every build.
    when(mockController.races).thenReturn([]);
    when(mockController.entries).thenReturn([]);
    when(mockController.runners).thenReturn([]);
    when(mockController.raceStarted).thenReturn(false);
    when(mockController.raceStopped).thenReturn(false);
    when(mockController.isListening).thenReturn(false);
    when(mockController.isProcessing).thenReturn(false);
    when(mockController.voiceReady).thenReturn(false);
    when(mockController.transcript).thenReturn('');
    when(mockController.lastAddedBib).thenReturn(null);
    when(mockController.selectedRace).thenReturn(null);
    when(mockController.addListener(any)).thenReturn(null);
    when(mockController.removeListener(any)).thenReturn(null);
    when(mockController.flagFor(any, excludeId: anyNamed('excludeId')))
        .thenReturn(null);
    when(mockController.runnerFor(any)).thenReturn(null);
  });

  Widget wrapLobby() => MaterialApp(
        home: Scaffold(body: RaceLobbyWidget(controller: mockController)),
      );

  Widget wrapRaceMode() => MaterialApp(
        home: Scaffold(body: RaceModeWidget(controller: mockController)),
      );

  group('RaceLobbyWidget', () {
    testWidgets('shows empty state when no races are loaded', (tester) async {
      when(mockController.races).thenReturn([]);

      await tester.pumpWidget(wrapLobby());
      await tester.pump();

      expect(find.text('No races yet'), findsOneWidget);
    });

    testWidgets('shows race card when a race is available', (tester) async {
      final race = RaceRecord(
        raceId: 1,
        date: DateTime(2026, 3, 15),
        name: 'State Meet',
        type: 'bibRecorderV2',
      );
      when(mockController.races).thenReturn([race]);

      await tester.pumpWidget(wrapLobby());
      await tester.pump();

      expect(find.text('State Meet'), findsOneWidget);
    });

    testWidgets('no entries shown in lobby state', (tester) async {
      when(mockController.races).thenReturn([]);

      await tester.pumpWidget(wrapLobby());
      await tester.pump();

      expect(find.byType(RaceModeWidget), findsNothing);
    });
  });

  group('RaceModeWidget', () {
    RaceRecord makeRace() => RaceRecord(
          raceId: 1,
          date: DateTime(2026),
          name: 'Test Race',
          type: 'bibRecorderV2',
        );

    setUp(() {
      when(mockController.selectedRace).thenReturn(makeRace());
    });

    testWidgets('shows bib entry cards when entries are present', (tester) async {
      when(mockController.entries).thenReturn([
        const BibEntry(id: 1, bib: 101),
        const BibEntry(id: 2, bib: 202),
      ]);

      await tester.pumpWidget(wrapRaceMode());
      await tester.pump();

      expect(find.text('101'), findsOneWidget);
      expect(find.text('202'), findsOneWidget);
    });

    testWidgets('shows duplicate flag chip for flagged bib', (tester) async {
      when(mockController.entries)
          .thenReturn([const BibEntry(id: 1, bib: 101)]);
      when(mockController.flagFor(101, excludeId: 1)).thenReturn('duplicate');

      await tester.pumpWidget(wrapRaceMode());
      await tester.pump();

      expect(find.textContaining('Duplicate'), findsOneWidget);
    });

    testWidgets('shows unknown flag chip for unrostered bib', (tester) async {
      when(mockController.entries)
          .thenReturn([const BibEntry(id: 1, bib: 999)]);
      when(mockController.flagFor(999, excludeId: 1)).thenReturn('unknown');

      await tester.pumpWidget(wrapRaceMode());
      await tester.pump();

      expect(find.textContaining('Not in roster'), findsOneWidget);
    });

    testWidgets('shows idle bib card state when lastAddedBib is null',
        (tester) async {
      when(mockController.entries).thenReturn([]);
      when(mockController.lastAddedBib).thenReturn(null);

      await tester.pumpWidget(wrapRaceMode());
      await tester.pump();

      // No bib number shown in the "last recorded" voice card area.
      expect(find.text('101'), findsNothing);
    });

    testWidgets('shows runner name badge when runner matches bib', (tester) async {
      final runner = Runner(
        raceId: 1,
        bibNumber: '101',
        name: 'Alice Smith',
        createdAt: DateTime(2026),
      );
      when(mockController.entries)
          .thenReturn([const BibEntry(id: 1, bib: 101)]);
      when(mockController.runnerFor(101)).thenReturn(runner);

      await tester.pumpWidget(wrapRaceMode());
      await tester.pump();

      expect(find.textContaining('Alice Smith'), findsOneWidget);
    });
  });
}
