import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/review_results/review_results_step.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/shared/models/database/race_result.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

import 'load_results_step_test.mocks.dart';

// The last page of collecting results shows what will be saved, and saves
// only when the coach says so.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLoadResultsController controller;

  final results = [
    RaceResult(
      raceId: 1,
      place: 1,
      runner: const Runner(runnerId: 1, name: 'Ann Lee', bibNumber: '101'),
      team: const Team(name: 'Eagles', abbreviation: 'EAG'),
      finishTime: const Duration(minutes: 16, seconds: 2),
    ),
    RaceResult(
      raceId: 1,
      place: 2,
      runner: const Runner(runnerId: 2, name: 'Bo Park', bibNumber: '202'),
      team: const Team(name: 'Hawks', abbreviation: 'HAW'),
      finishTime: const Duration(minutes: 16, seconds: 30),
    ),
  ];

  setUpAll(() {
    provideDummy<({List<RaceResult> results, AppError? error})>(
        (results: const <RaceResult>[], error: null));
  });

  setUp(() {
    controller = MockLoadResultsController();
    when(controller.addListener(any)).thenReturn(null);
    when(controller.removeListener(any)).thenReturn(null);
    when(controller.buildResults())
        .thenReturn((results: results, error: null));
  });

  testWidgets('lists each finisher in order with their time', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ReviewResultsList(controller: controller)),
    ));

    expect(find.text('2 finishers from 2 teams'), findsOneWidget);
    expect(find.text('Ann Lee'), findsOneWidget);
    expect(find.text('EAG · Bib 101'), findsOneWidget);
    expect(find.text('16:02.00'), findsOneWidget);
    expect(find.text('Bo Park'), findsOneWidget);
  });

  testWidgets('says why when the results cannot be saved yet',
      (tester) async {
    when(controller.buildResults()).thenReturn((
      results: const <RaceResult>[],
      error: const AppError(userMessage: 'No results are loaded to save.'),
    ));
    final step = ReviewResultsStep(controller: controller);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ReviewResultsList(controller: controller)),
    ));

    expect(find.text('No results are loaded to save.'), findsOneWidget);
    expect(step.canProceed!(), isFalse);
    expect(step.blockedReason!(), 'No results are loaded to save.');
    step.dispose();
  });

  test('saves the results when the coach taps Save Results', () async {
    when(controller.saveCurrentResults()).thenAnswer((_) async => null);
    final step = ReviewResultsStep(controller: controller);

    expect(step.nextLabel, 'Save Results');
    expect(step.canProceed!(), isTrue);
    await step.onNext!();

    verify(controller.saveCurrentResults()).called(1);
    step.dispose();
  });

  test('stays on the page when saving fails', () async {
    // Finishing anyway would mark the race done without its results.
    when(controller.saveCurrentResults()).thenAnswer(
        (_) async => const AppError(userMessage: 'Could not save the results.'));
    final step = ReviewResultsStep(controller: controller);

    await expectLater(
      step.onNext!(),
      throwsA(isA<FlowStepBlocked>().having(
          (e) => e.message, 'message', 'Could not save the results.')),
    );
    step.dispose();
  });
}
