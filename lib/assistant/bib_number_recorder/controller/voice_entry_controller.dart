import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/haptic_feedback_service.dart';
import 'package:xceleration/core/utils/logger.dart';

import '../services/i_voice_recognition_service.dart';
import '../services/voice_recognition_service.dart';

/// Where voice entry is up to.
enum VoiceEntryState {
  /// The volunteer types bibs; voice is not loaded.
  off,

  /// Loading the speech model, downloading it the first time.
  preparing,

  /// Waiting for the volunteer to hold the mic.
  ready,

  /// Recording while the mic is held.
  listening,

  /// Turning the recording into a bib.
  processing,

  /// Voice could not be set up; the keypad still works.
  failed,
}

/// Voice entry for the Bib Recorder: hold the mic, say the bib, let go, and
/// the bib is added as the next runner.
///
/// The choice to use voice is remembered on the phone. The speech model is
/// only loaded once voice is turned on, so volunteers who type never
/// download it.
class VoiceEntryController extends ChangeNotifier {
  VoiceEntryController({
    required this.onBibHeard,
    IVoiceRecognitionService Function()? createService,
    IHapticFeedback? haptics,
    Future<SharedPreferences> Function()? prefs,
  })  : _createService = createService ?? VoiceRecognitionService.create,
        _haptics = haptics ?? HapticFeedbackService(),
        _prefs = prefs ?? SharedPreferences.getInstance;

  /// The preference that remembers voice entry is on.
  static const prefKey = 'bib_recorder_voice_entry';

  /// Adds a heard bib to the list.
  final Future<void> Function(String bib) onBibHeard;

  final IVoiceRecognitionService Function() _createService;
  final IHapticFeedback _haptics;
  final Future<SharedPreferences> Function() _prefs;

  IVoiceRecognitionService? _service;
  StreamSubscription<String?>? _bibSub;
  bool _disposed = false;

  VoiceEntryState _state = VoiceEntryState.off;
  VoiceEntryState get state => _state;

  /// Whether the volunteer has chosen voice, even while it is loading.
  bool get enabled => _state != VoiceEntryState.off;

  /// Why voice could not be set up, when [state] is failed.
  AppError? _error;
  AppError? get error => _error;

  /// The last bib heard, shown so the volunteer can check it.
  String? _lastHeard;
  String? get lastHeard => _lastHeard;

  /// True when the last recording held no bib that could be made out.
  bool _missed = false;
  bool get missed => _missed;

  /// Turns voice on if the volunteer chose it last time.
  Future<void> restore() async {
    try {
      final prefs = await _prefs();
      if (prefs.getBool(prefKey) ?? false) await _prepare();
    } catch (e) {
      Logger.e('[VoiceEntryController.restore] $e');
    }
  }

  /// Turns voice entry on or off, and remembers the choice.
  Future<void> setEnabled(bool on) async {
    try {
      (await _prefs()).setBool(prefKey, on);
    } catch (e) {
      Logger.e('[VoiceEntryController.setEnabled] $e');
    }
    if (on) {
      await _prepare();
    } else {
      await _release();
      _set(VoiceEntryState.off);
    }
  }

  /// Tries setting voice up again after it failed.
  Future<void> retry() => _prepare();

  Future<void> _prepare() async {
    if (_state == VoiceEntryState.preparing ||
        _state == VoiceEntryState.ready) {
      return;
    }
    _error = null;
    _set(VoiceEntryState.preparing);
    await _release();
    final service = _createService();
    _service = service;
    _bibSub = service.bibNumbers.listen(_onBib);
    final result = await service.initialize();
    if (_disposed || _service != service) return;
    switch (result) {
      case Success():
        _set(VoiceEntryState.ready);
      case Failure(:final error):
        Logger.e('[VoiceEntryController] ${error.originalException}');
        _error = error;
        await _release();
        _set(VoiceEntryState.failed);
    }
  }

  /// The mic is pressed: start recording.
  Future<void> startListening() async {
    if (_state != VoiceEntryState.ready) return;
    _missed = false;
    _set(VoiceEntryState.listening);
    await _service?.start();
  }

  /// The mic is let go: stop and make out the bib.
  Future<void> stopListening() async {
    if (_state != VoiceEntryState.listening) return;
    _set(VoiceEntryState.processing);
    await _service?.stop();
  }

  Future<void> _onBib(String? bib) async {
    if (_disposed) return;
    if (bib == null) {
      _missed = true;
      _haptics.vibrate();
    } else {
      _missed = false;
      _lastHeard = bib;
      _haptics.lightImpact();
      await onBibHeard(bib);
    }
    if (_state == VoiceEntryState.processing) {
      _set(VoiceEntryState.ready);
    } else {
      notifyListeners();
    }
  }

  /// Forgets the last bib shown, after the volunteer takes it back.
  void clearLastHeard() {
    _lastHeard = null;
    notifyListeners();
  }

  Future<void> _release() async {
    await _bibSub?.cancel();
    _bibSub = null;
    final service = _service;
    _service = null;
    await service?.dispose();
  }

  void _set(VoiceEntryState state) {
    _state = state;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_release());
    super.dispose();
  }
}
