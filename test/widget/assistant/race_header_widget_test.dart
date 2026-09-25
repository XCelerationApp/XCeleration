import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/widgets/race_header_widget.dart';
import 'package:xceleration/core/utils/enums.dart';

// Clearing everything recorded lives in the race menu, not beside Share,
// and only once there is something to clear.

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(
        Directory.systemTemp.createTempSync('race_header').path);
  });

  final race = RaceRecord(
      raceId: 3, date: DateTime(2026, 9, 26), name: 'Invitational', type: 'x');

  Future<void> openMenu(WidgetTester tester,
      {required bool canClear, VoidCallback? onClear}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RaceHeaderWidget(
          currentRace: race,
          role: DeviceName.raceTimer,
          onLoadRace: () {},
          clearRecordsLabel: 'Clear Times',
          canClearRecords: () => canClear,
          onClearRecords: onClear ?? () {},
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  testWidgets('offers to clear the times once there are some', (tester) async {
    var cleared = false;
    await openMenu(tester, canClear: true, onClear: () => cleared = true);

    await tester.tap(find.text('Clear Times'));
    await tester.pumpAndSettle();

    expect(cleared, isTrue);
  });

  testWidgets('leaves it out while there is nothing to clear', (tester) async {
    await openMenu(tester, canClear: false);

    expect(find.text('Clear Times'), findsNothing);
    expect(find.text('Get Race from Coach'), findsOneWidget);
  });

  group('the practice race', () {
    final practice = RaceRecord(
        raceId: -1, date: DateTime(2026, 9, 26), name: 'Demo Race', type: 'x');

    Future<void> show(WidgetTester tester, RaceRecord shown,
        {required VoidCallback onLoad, bool compact = false}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RaceHeaderWidget(
            currentRace: shown,
            role: DeviceName.raceTimer,
            onLoadRace: onLoad,
            compact: compact,
          ),
        ),
      ));
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
    }

    testWidgets('says it is practice and offers the real race',
        (tester) async {
      var asked = false;
      await show(tester, practice, onLoad: () => asked = true);

      expect(find.textContaining('This is a practice race'), findsOneWidget);
      await tester.tap(find.text('Get Race from Coach'));

      expect(asked, isTrue);
    });

    testWidgets('says nothing of the sort for the coach\'s race',
        (tester) async {
      await show(tester, race, onLoad: () {});

      expect(find.textContaining('practice'), findsNothing);
    });

    testWidgets('shrinks to a small tag while the race runs', (tester) async {
      await show(tester, practice, onLoad: () {}, compact: true);

      expect(find.text('Practice'), findsOneWidget);
      expect(find.textContaining('This is a practice race'), findsNothing);
    });
  });

  testWidgets('says nothing about a race while one is loading',
      (tester) async {
    Widget header({required bool loading}) => MaterialApp(
          home: Scaffold(
            body: RaceHeaderWidget(
              currentRace: null,
              role: DeviceName.bibRecorder,
              onLoadRace: () {},
              loading: loading,
            ),
          ),
        );

    await tester.pumpWidget(header(loading: true));
    // Not "No race yet" for the moment before the race appears.
    expect(find.text('No race yet'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(header(loading: false));
    expect(find.text('No race yet'), findsOneWidget);
  });
}
