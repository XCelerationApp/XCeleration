import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/haptic_feedback_service.dart';
import 'package:xceleration/core/utils/logger.dart';

import '../services/i_voice_recognition_service.dart';
import '../services/model_download_service.dart';
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
/// downloaded as soon as the Bib Recorder opens, so it is on the phone
/// before the race even if voice is only turned on then; it is loaded into
/// memory only once voice is on.
class VoiceEntryController extends ChangeNotifier {
  VoiceEntryController({
    required this.onBibHeard,
    IVoiceRecognitionService Function()? createService,
    IHapticFeedback? haptics,
    Future<SharedPreferences> Function()? prefs,
    Future<void> Function()? fetchModel,
    bool Function(String bib)? isKnownBib,
  })  : _createService = createService ??
            (() => VoiceRecognitionService.create(isKnownBib: isKnownBib)),
        _haptics = haptics ?? HapticFeedbackService(),
        _prefs = prefs ?? SharedPreferences.getInstance,
        _fetchModel = fetchModel ?? _downloadModel;

  /// The preference that remembers voice entry is on.
  static const prefKey = 'bib_recorder_voice_entry';

  /// Set while the speech model loads. Still set when the Bib Recorder next
  /// opens means the app closed part way through, most likely because
  /// loading voice crashed it; voice is then left off rather than crashing
  /// the app again each time the Bib Recorder opens.
  static const loadingKey = 'bib_recorder_voice_loading';

  static Future<void> _downloadModel() async {
    await ModelDownloadService().ensureModelReady();
  }

  /// Adds a heard bib to the list.
  final Future<void> Function(String bib) onBibHeard;

  final IVoiceRecognitionService Function() _createService;
  final IHapticFeedback _haptics;
  final Future<SharedPreferences> Function() _prefs;
  final Future<void> Function() _fetchModel;

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

  /// Counts the bibs heard, so the same bib heard twice still shows as new.
  int _heardCount = 0;
  int get heardCount => _heardCount;

  /// True when the last recording held no bib that could be made out.
  bool _missed = false;
  bool get missed => _missed;

  /// How long the mic was held. A tap too short to say a bib in that hears
  /// nothing was a slip of the thumb, so it is let go without a buzz.
  final Stopwatch _held = Stopwatch();
  static const _slip = Duration(milliseconds: 400);

  /// Turns voice on if the volunteer chose it last time, and otherwise
  /// fetches the speech model in the background so it is ready if they do.
  Future<void> restore() async {
    try {
      final prefs = await _prefs();
      if (prefs.getBool(loadingKey) ?? false) {
        await prefs.setBool(loadingKey, false);
        await prefs.setBool(prefKey, false);
        _error = const AppError(
          // The panel adds "Use the keypad, or try again."
          userMessage: 'Voice entry closed the app last time it started, so '
              'it was turned off.',
        );
        _set(VoiceEntryState.failed);
        return;
      }
      if (prefs.getBool(prefKey) ?? false) {
        await _prepare();
      } else {
        unawaited(_fetchModel().catchError((Object e) {
          // Tried again when voice is turned on.
          Logger.d('[VoiceEntryController] Model not fetched early: $e');
        }));
      }
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
    await _markLoading(true);
    final result = await service.initialize();
    await _markLoading(false);
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

  Future<void> _markLoading(bool loading) async {
    try {
      await (await _prefs()).setBool(loadingKey, loading);
    } catch (e) {
      Logger.e('[VoiceEntryController._markLoading] $e');
    }
  }

  /// The mic is pressed: start recording.
  Future<void> startListening() async {
    if (_state != VoiceEntryState.ready) return;
    _missed = false;
    // A firm tap as the mic opens and a lighter one as it closes, so the
    // volunteer feels both without looking.
    _haptics.mediumImpact();
    _held
      ..reset()
      ..start();
    _set(VoiceEntryState.listening);
    await _service?.start();
  }

  /// The mic is let go: stop and make out the bib.
  Future<void> stopListening() async {
    if (_state != VoiceEntryState.listening) return;
    _haptics.selectionClick();
    _held.stop();
    _set(VoiceEntryState.processing);
    await _service?.stop();
  }

  Future<void> _onBib(String? bib) async {
    if (_disposed) return;
    if (bib == null) {
      final slip = _held.elapsed < _slip;
      _missed = !slip;
      if (!slip) _haptics.vibrate();
    } else {
      _missed = false;
      _lastHeard = bib;
      _heardCount++;
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
