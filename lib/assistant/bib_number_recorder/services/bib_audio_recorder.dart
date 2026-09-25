import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart' show Level;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/i_bib_audio_recorder.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';

/// [IBibAudioRecorder] implementation backed by [FlutterSoundRecorder].
///
/// Records 16 kHz mono PCM WAV to a temporary file.
class BibAudioRecorder implements IBibAudioRecorder {
  BibAudioRecorder({
    FlutterSoundRecorder? recorder,
    Future<Directory> Function()? tempDirProvider,
  })  : _recorder = recorder ?? FlutterSoundRecorder(logLevel: Level.warning),
        _tempDirProvider = tempDirProvider ?? getTemporaryDirectory;

  final FlutterSoundRecorder _recorder;

  /// Returns the directory used for the temporary WAV file.
  final Future<Directory> Function() _tempDirProvider;

  bool _isOpen = false;
  String? _recordingPath;

  static const _audioSession = MethodChannel('xceleration/audio_session');

  /// iOS mutes haptics while recording, so the tap as the mic button goes
  /// down was never felt. Asked again before each recording, in case the
  /// recorder set the audio session up afresh.
  Future<void> _allowHapticsWhileRecording() async {
    try {
      await _audioSession.invokeMethod<void>('allowHapticsWhileRecording');
    } on MissingPluginException {
      // Android and tests: haptics are not muted there.
    } catch (_) {
      // Best effort: recording matters more than the tap.
    }
  }

  @override
  Future<Result<void>> open() async {
    try {
      await _recorder.openRecorder();
      _isOpen = true;
      await _allowHapticsWhileRecording();
      await _warmUpAudioSession();
      return const Success(null);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not open audio recorder.',
        originalException: e,
      ));
    }
  }

  /// Activates AVAudioSession by doing a silent start/stop during initialisation.
  ///
  /// On iOS, the first call to startRecorder triggers AVAudioSession activation
  /// on the platform thread, which can block Flutter's frame pipeline and cause
  /// a visible ~500 ms delay before the first UI state change. Running a
  /// dummy start/stop here — where the delay is invisible — ensures the session
  /// is warm by the time the user presses the button.
  Future<void> _warmUpAudioSession() async {
    final tmp = await _tempDirProvider();
    final warmupPath = p.join(tmp.path, 'warmup.wav');
    try {
      await _recorder.startRecorder(
        toFile: warmupPath,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );
      await _recorder.stopRecorder();
    } catch (_) {
      // Warm-up is best-effort — failures are silently ignored.
    } finally {
      final f = File(warmupPath);
      if (f.existsSync()) f.deleteSync();
    }
  }

  @override
  Future<void> start() async {
    if (!_isOpen) return;

    final tmp = await _tempDirProvider();
    _recordingPath = p.join(tmp.path, 'bib_recording.wav');

    final existing = File(_recordingPath!);
    if (existing.existsSync()) existing.deleteSync();

    await _allowHapticsWhileRecording();
    await _recorder.startRecorder(
      toFile: _recordingPath,
      codec: Codec.pcm16WAV,
      sampleRate: 16000,
      numChannels: 1,
    );
  }

  @override
  Future<String?> stop() async {
    final stoppedPath = await _recorder.stopRecorder();
    final path = stoppedPath ?? _recordingPath;
    _recordingPath = null;

    if (path == null || !File(path).existsSync()) return null;
    return path;
  }

  @override
  Future<void> close() async {
    if (_isOpen) {
      await _recorder.closeRecorder();
      _isOpen = false;
    }
  }
}
