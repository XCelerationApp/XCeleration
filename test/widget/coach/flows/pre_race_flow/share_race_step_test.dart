import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';
import 'package:xceleration/coach/flows/pre_race_flow/steps/share_race/share_race_step.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/enums.dart';

// Done on Send to Volunteers. If a phone has not received the race here, the
// coach is asked first, rather than told "Race sent" either way.

void main() {
  late DevicesManager devices;

  setUp(() => devices = DevicesManager(
      DeviceName.coach, DeviceType.advertiserDevice,
      data: 'race'));

  /// Presses Done and answers the dialog, if one shows, with [answer].
  /// Returns whether the step let the coach finish.
  Future<bool> done(WidgetTester tester, {String? answer}) async {
    bool? finished;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              try {
                await ShareRaceStep.confirmUnsent(context, devices);
                finished = true;
              } on FlowStepBlocked {
                finished = false;
              }
            },
            child: const Text('Done'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    if (answer != null) {
      expect(find.text('Not Received Yet'), findsOneWidget);
      await tester.tap(find.text(answer).last);
      await tester.pumpAndSettle();
    }
    return finished!;
  }

  testWidgets('finishes without asking once both phones have it',
      (tester) async {
    devices.raceTimer!.status = ConnectionStatus.finished;
    devices.bibRecorder!.status = ConnectionStatus.finished;

    expect(await done(tester), isTrue);
  });

  testWidgets('asks when a phone has not received it, and can wait',
      (tester) async {
    devices.raceTimer!.status = ConnectionStatus.finished;

    expect(await done(tester, answer: 'Keep Waiting'), isFalse);
  });

  testWidgets('names who is waiting, and can still finish (QR code)',
      (tester) async {
    expect(await done(tester, answer: 'Done'), isTrue);
  });

  testWidgets('says which phones are waiting', (tester) async {
    devices.bibRecorder!.status = ConnectionStatus.finished;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              ShareRaceStep.confirmUnsent(context, devices).catchError((_) {}),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.textContaining('The Timer has not received'), findsOneWidget);
  });
}
