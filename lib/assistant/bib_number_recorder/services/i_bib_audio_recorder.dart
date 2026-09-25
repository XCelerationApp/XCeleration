import 'package:xceleration/core/result.dart';

/// Abstraction over a platform audio recorder that writes 16 kHz mono WAV files.
///
/// Lifecycle: [open] → [start] / [stop] (repeatable) → [close].
abstract interface class IBibAudioRecorder {
  /// Opens the underlying recorder session. Must be called before [start].
  Future<Result<void>> open();

  /// Begins recording to a temporary WAV file.
  Future<void> start();

  /// Stops recording and returns the path to the WAV file, or null if nothing
  /// was captured.
  Future<String?> stop();

  /// Releases the recorder session. Call when the recorder is no longer needed.
  Future<void> close();
}
