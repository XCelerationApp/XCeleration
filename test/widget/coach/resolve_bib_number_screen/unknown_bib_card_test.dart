import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/bib_conflict_resolution/model/bib_conflict.dart';
import 'package:xceleration/coach/resolve_bib_number_screen/widgets/unknown_bib_card.dart';

// Resolving a bib no runner has.

Future<void> _pump(WidgetTester tester, UnknownBibConflict conflict) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: UnknownBibCard(
          conflict: conflict,
          buildAssignment: (_) => const Text('assign or create'),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('asks who finished there, and when', (tester) async {
    await _pump(
      tester,
      const UnknownBibConflict(
        bibNumber: '99',
        occurrence: ConflictOccurrence(place: 4, time: '15:42.60'),
      ),
    );

    expect(find.text('#99'), findsOneWidget);
    expect(find.text('Who finished 4th?'), findsOneWidget);
    expect(find.textContaining('15:42.60'), findsOneWidget);
    expect(find.textContaining('No runner has bib #99'), findsOneWidget);
    expect(find.text('assign or create'), findsOneWidget);
  });

  testWidgets('shows who finished either side', (tester) async {
    await _pump(
      tester,
      const UnknownBibConflict(
        bibNumber: '99',
        occurrence: ConflictOccurrence(place: 4, time: '15:42.60', nearby: [
          NearbyFinisher(
              place: 3, name: 'Bo Nguyen', team: 'Hawks', bibNumber: '301'),
          NearbyFinisher(
              place: 5, name: 'Cy Diaz', team: 'Owls', bibNumber: '302'),
        ]),
      ),
    );

    // Who they came in between is often the only way to work out who it was.
    expect(find.text('3. Bo Nguyen'), findsOneWidget);
    expect(find.text('5. Cy Diaz'), findsOneWidget);
  });

  testWidgets('copes with the Timer not having settled that place',
      (tester) async {
    await _pump(
      tester,
      const UnknownBibConflict(
        bibNumber: '99',
        occurrence: ConflictOccurrence(place: 4),
      ),
    );

    expect(find.text('Who finished 4th?'), findsOneWidget);
    expect(find.textContaining('No runner has bib #99'), findsOneWidget);
  });
}
