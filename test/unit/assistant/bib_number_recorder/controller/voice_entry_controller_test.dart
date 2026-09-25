import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/assistant/bib_number_recorder/controller/voice_entry_controller.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/i_voice_recognition_service.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/haptic_feedback_service.dart';

// A volunteer holds the mic, says a bib and lets go; the bib must be added
// as the next runner. When nothing can be made out, the phone buzzes and
// nothing is added.

class _FakeVoice implements IVoiceRecognitionService {
  _FakeVoice({this.initResult = const Success(null)});

  final Result<void> initResult;
  final _bibs = StreamController<String?>.broadcast();
  final _partials = StreamController<String>.broadcast();

  /// What the next recording will turn out to say.
  String? nextHeard;
  bool started = false;
  bool disposed = false;

  @override
  Stream<String?> get bibNumbers => _bibs.stream;

  @override
  Stream<String> get partialResults => _partials.stream;

  @override
  Future<Result<void>> initialize() async => initResult;

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> stop() async => _bibs.add(nextHeard);

  @override
  Future<void> dispose() async {
    disposed = true;
    await _bibs.close();
    await _partials.close();
  }
}

class _Haptics implements IHapticFeedback {
  int buzzes = 0;
  int taps = 0;
  int presses = 0;
  int releases = 0;

  @override
  Future<void> vibrate() async => buzzes++;

  @override
  Future<void> lightImpact() async => taps++;

  @override
  Future<void> mediumImpact() async => presses++;

  @override
  Future<void> selectionClick() async => releases++;
}

void main() {
  late List<String> added;
  late _FakeVoice voice;
  late _Haptics haptics;
  late int created;

  VoiceEntryController build({Result<void> init = const Success(null)}) {
    return VoiceEntryController(
      onBibHeard: (bib) async => added.add(bib),
      createService: () {
        created++;
        return voice = _FakeVoice(initResult: init);
      },
      haptics: haptics,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    added = [];
    haptics = _Haptics();
    created = 0;
  });

  test('is off until turned on, and loads nothing meanwhile', () async {
    final c = build();
    await c.restore();

    expect(c.state, VoiceEntryState.off);
    expect(created, 0, reason: 'volunteers who type never load the model');
    c.dispose();
  });

  test('adds the bib heard when the mic is let go', () async {
    final c = build();
    await c.setEnabled(true);
    expect(c.state, VoiceEntryState.ready);

    voice.nextHeard = '0412';
    await c.startListening();
    expect(c.state, VoiceEntryState.listening);
    expect(voice.started, isTrue);
    await c.stopListening();
    await Future<void>.delayed(Duration.zero);

    expect(added, ['0412']);
    expect(c.lastHeard, '0412');
    expect(c.state, VoiceEntryState.ready);
    expect(haptics.taps, 1);
    c.dispose();
  });

  test('taps when the mic is pressed and again when it is let go', () async {
    final c = build();
    await c.setEnabled(true);

    voice.nextHeard = '12';
    await c.startListening();
    expect(haptics.presses, 1);
    expect(haptics.releases, 0);
    await c.stopListening();
    expect(haptics.releases, 1);
    c.dispose();
  });

  test('buzzes and adds nothing when no bib can be made out', () async {
    final c = build();
    await c.setEnabled(true);

    voice.nextHeard = null;
    await c.startListening();
    await c.stopListening();
    await Future<void>.delayed(Duration.zero);

    expect(added, isEmpty);
    expect(c.missed, isTrue);
    expect(haptics.buzzes, 1);
    expect(c.state, VoiceEntryState.ready, reason: 'ready to try again');
    c.dispose();
  });

  test('ignores the mic until the model is ready', () async {
    final c = build();
    await c.startListening();

    expect(c.state, VoiceEntryState.off);
    c.dispose();
  });

  test('remembers the choice for next time', () async {
    final first = build();
    await first.setEnabled(true);
    first.dispose();

    final again = build();
    await again.restore();

    expect(again.state, VoiceEntryState.ready);
    again.dispose();
  });

  test('turning it off lets the model go and remembers that too', () async {
    final c = build();
    await c.setEnabled(true);
    final loaded = voice;

    await c.setEnabled(false);

    expect(c.state, VoiceEntryState.off);
    expect(loaded.disposed, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(VoiceEntryController.prefKey), isFalse);
    c.dispose();
  });

  test('says why when voice cannot be set up, and can try again', () async {
    final c = build(
        init: const Failure(
            AppError(userMessage: 'Could not load speech recognition model.')));
    await c.setEnabled(true);

    expect(c.state, VoiceEntryState.failed);
    expect(c.error?.userMessage, 'Could not load speech recognition model.');
    expect(voice.disposed, isTrue);

    await c.retry();

    expect(created, 2);
    c.dispose();
  });
}
