import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/flows/pre_race_flow/steps/review_runners/review_runners_step.dart';
import 'package:xceleration/shared/models/database/master_race.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MasterRace masterRace;

  setUp(() {
    masterRace = MasterRace.getInstance(1);
  });

  tearDown(() {
    MasterRace.clearInstance(1);
  });

  ReviewRunnersStep buildStep({
    required Future<bool> Function(MasterRace) checkMinimumRunners,
  }) {
    return ReviewRunnersStep(
      masterRace: masterRace,
      onNext: () async {},
      checkMinimumRunners: checkMinimumRunners,
    );
  }

  // ===========================================================================
  group('ReviewRunnersStep', () {
    // -------------------------------------------------------------------------
    group('seedInitialProceed', () {
      test('sets canProceed to true when checker returns true', () async {
        final step = buildStep(checkMinimumRunners: (_) async => true);
        await step.seedInitialProceed();

        expect(step.canProceed(), isTrue);
        step.dispose();
      });

      test('sets canProceed to false when checker returns false', () async {
        final step = buildStep(checkMinimumRunners: (_) async => false);
        await step.seedInitialProceed();

        expect(step.canProceed(), isFalse);
        step.dispose();
      });
    });

    // -------------------------------------------------------------------------
    group('checkRunners', () {
      test('notifies content changed when canProceed value changes', () async {
        var returnValue = false;
        final step =
            buildStep(checkMinimumRunners: (_) async => returnValue);

        // Let the constructor's unawaited checkRunners() settle (false→false, no notify)
        await Future.microtask(() {});

        final events = <void>[];
        step.onContentChange.listen((_) => events.add(null));

        // Change the value so the next checkRunners() transitions false→true
        returnValue = true;
        await step.checkRunners();
        await Future.microtask(() {}); // let stream deliver event

        expect(events, hasLength(1));
        step.dispose();
      });

      test('does not notify when canProceed value is unchanged', () async {
        final step = buildStep(checkMinimumRunners: (_) async => true);

        // Seed _canProceed to true, then let the constructor's checkRunners settle
        await step.seedInitialProceed();
        await Future.microtask(() {});

        final events = <void>[];
        step.onContentChange.listen((_) => events.add(null));

        // Call checkRunners with the same value (true→true, no change)
        await step.checkRunners();

        expect(events, isEmpty);
        step.dispose();
      });
    });
  });
}
