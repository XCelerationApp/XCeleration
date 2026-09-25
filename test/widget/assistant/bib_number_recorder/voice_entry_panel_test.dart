import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/assistant/bib_number_recorder/controller/voice_entry_controller.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/i_voice_recognition_service.dart';
import 'package:xceleration/assistant/bib_number_recorder/widgets/voice_entry_panel.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/haptic_feedback_service.dart';

class _FakeVoice implements IVoiceRecognitionService {
  _FakeVoice(this.init);

  final Future<Result<void>> Function() init;
  final _bibs = StreamController<String?>.broadcast();
  String? nextHeard;
  bool started = false;

  @override
  Stream<String?> get bibNumbers => _bibs.stream;
  @override
  Stream<String> get partialResults => const Stream.empty();
  @override
  Future<Result<void>> initialize() => init();
  @override
  Future<void> start() async => started = true;
  @override
  Future<void> stop() async => _bibs.add(nextHeard);
  @override
  Future<void> dispose() => _bibs.close();
}

class _NoHaptics implements IHapticFeedback {
  @override
  Future<void> vibrate() async {}
  @override
  Future<void> lightImpact() async {}
  @override
  Future<void> mediumImpact() async {}
  @override
  Future<void> selectionClick() async {}
}

void main() {
  late List<String> added;
  late _FakeVoice fake;
  late int undone;

  VoiceEntryController build(Future<Result<void>> Function() init) =>
      VoiceEntryController(
        onBibHeard: (bib) async => added.add(bib),
        createService: () => fake = _FakeVoice(init),
        haptics: _NoHaptics(),
      );

  Widget host(VoiceEntryController voice) => MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: voice,
            builder: (_, _) => Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                EntryModeToggle(voice: voice),
                VoiceEntryPanel(
                  voice: voice,
                  describe: (bib) => bib == '42' ? 'Alice, EAG' : null,
                  onUndo: () => undone++,
                ),
              ],
            ),
          ),
        ),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    added = [];
    undone = 0;
  });

  testWidgets('Voice turns on from the switch, and holding the button '
      'records a bib', (tester) async {
    final voice = build(() async => const Success(null));
    await tester.pumpWidget(host(voice));
    expect(find.text('Hold and Say Bib'), findsNothing);

    await tester.tap(find.text('Voice'));
    await tester.pumpAndSettle();
    expect(find.text('Hold and Say Bib'), findsOneWidget);

    fake.nextHeard = '42';
    final finger =
        await tester.startGesture(tester.getCenter(find.text('Hold and Say Bib')));
    await tester.pump();
    expect(fake.started, isTrue);
    expect(find.text('Listening…'), findsOneWidget);

    await finger.up();
    await tester.pumpAndSettle();

    expect(added, ['42']);
    expect(find.text('Heard 42 · Alice, EAG'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    expect(undone, 1);
    voice.dispose();
  });

  testWidgets('says when a bib is not on the roster', (tester) async {
    final voice = build(() async => const Success(null));
    await voice.setEnabled(true);
    await tester.pumpWidget(host(voice));

    fake.nextHeard = '901';
    final finger =
        await tester.startGesture(tester.getCenter(find.text('Hold and Say Bib')));
    await tester.pump();
    await finger.up();
    await tester.pumpAndSettle();

    expect(find.text('Heard 901 (not on the roster)'), findsOneWidget);
    voice.dispose();
  });

  testWidgets('asks to try again when nothing was made out', (tester) async {
    final voice = build(() async => const Success(null));
    await voice.setEnabled(true);
    await tester.pumpWidget(host(voice));

    fake.nextHeard = null;
    final finger =
        await tester.startGesture(tester.getCenter(find.text('Hold and Say Bib')));
    await tester.pump();
    await finger.up();
    await tester.pumpAndSettle();

    expect(find.textContaining('Didn\'t catch that'), findsOneWidget);
    expect(added, isEmpty);
    voice.dispose();
  });

  testWidgets('warns about the download while the model loads',
      (tester) async {
    final loading = Completer<Result<void>>();
    final voice = build(() => loading.future);
    await tester.pumpWidget(host(voice));

    await tester.tap(find.text('Voice'));
    await tester.pump();

    expect(find.textContaining('downloads about 28 MB'), findsOneWidget);
    expect(find.text('Hold and Say Bib'), findsNothing);

    loading.complete(const Success(null));
    await tester.pumpAndSettle();
    expect(find.text('Hold and Say Bib'), findsOneWidget);
    voice.dispose();
  });

  testWidgets('offers the keypad and another try when voice fails',
      (tester) async {
    final voice = build(() async =>
        const Failure(AppError(userMessage: 'Could not open audio recorder.')));
    // The failure is logged, which uses real time.
    await tester.runAsync(() => voice.setEnabled(true));
    await tester.pumpWidget(host(voice));

    expect(find.textContaining('Could not open audio recorder.'),
        findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    voice.dispose();
  });
}
