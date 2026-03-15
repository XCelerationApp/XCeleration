import 'dart:io';

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

  @override
  Future<Result<void>> open() async {
    try {
      await _recorder.openRecorder();
      _isOpen = true;
      return const Success(null);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not open audio recorder.',
        originalException: e,
      ));
    }
  }

  @override
  Future<void> start() async {
    if (!_isOpen) return;

    final tmp = await _tempDirProvider();
    _recordingPath = p.join(tmp.path, 'bib_recording.wav');

    final existing = File(_recordingPath!);
    if (existing.existsSync()) existing.deleteSync();

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
