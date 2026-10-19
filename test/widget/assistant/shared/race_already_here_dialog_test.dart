import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/services/received_race_resolver.dart';
import 'package:xceleration/assistant/shared/widgets/race_already_here_dialog.dart';

// A race the coach sends that is already on the phone: the volunteer is told
// what is recorded and chooses between updating it and keeping it apart.

void main() {
  RaceRecord race(String name, {int day = 12}) => RaceRecord(
    raceId: 3,
    date: DateTime(2026, 9, day),
    name: name,
    type: 'race',
  );

  final resent = RaceAlreadyHere(
    existing: race('Invitational'),
    sent: race('Invitational'),
    recorded: 18,
    rosterChanges: const RosterChanges(added: 3),
  );
  final renamed = RaceAlreadyHere(
    existing: race('Invitational'),
    sent: race('Saturday Invitational'),
    recorded: 1,
  );

  group('the words', () {
    test('for a race sent again name what is kept and the roster change', () {
      final text = raceAlreadyHereText(resent, 'bibs');

      expect(text.title, 'Race already on this phone');
      expect(text.content, contains('with 18 bibs recorded'));
      expect(text.content, contains('3 runners: 3 added'));
      expect((text.update, text.keep), ('Update race', 'Make a copy'));
    });

    test('for a renamed race ask whether it is the same', () {
      final text = raceAlreadyHereText(renamed, 'times');

      expect(text.title, 'Is this the same race?');
      expect(text.content, contains('"Saturday Invitational"'));
      expect(text.content, contains('with 1 time recorded'));
      expect((text.update, text.keep), ('Same race', 'Keep both'));
    });
  });

  group('the dialog', () {
    /// Opens the dialog; the returned function reads what was chosen.
    Future<ReceivedRaceChoice? Function()> open(WidgetTester tester) async {
      ReceivedRaceChoice? choice;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  choice = await askAboutRace(context, resent, what: 'bibs'),
              child: const Text('receive'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('receive'));
      await tester.pumpAndSettle();
      return () => choice;
    }

    testWidgets('Update race updates it', (tester) async {
      final chosen = await open(tester);

      await tester.tap(find.text('Update race'));
      await tester.pumpAndSettle();

      expect(chosen(), ReceivedRaceChoice.update);
    });

    testWidgets('Make a copy keeps it apart', (tester) async {
      final chosen = await open(tester);

      await tester.tap(find.text('Make a copy'));
      await tester.pumpAndSettle();

      expect(chosen(), ReceivedRaceChoice.keepSeparate);
    });

    testWidgets('a tap outside does not choose', (tester) async {
      final chosen = await open(tester);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.text('Race already on this phone'), findsOneWidget);
      expect(chosen(), isNull);
    });
  });
}
