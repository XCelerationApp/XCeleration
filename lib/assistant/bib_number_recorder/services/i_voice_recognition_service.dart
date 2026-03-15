import 'package:xceleration/core/result.dart';

/// Orchestrates audio recording and offline speech-to-bib-number recognition.
///
/// Lifecycle: [initialize] → [start] / [stop] (repeatable) → [dispose].
abstract interface class IVoiceRecognitionService {
  /// Emits a recognised bib number (1–9999), or null when no valid number was
  /// heard. Emitted once per [stop] call.
  Stream<int?> get bibNumbers;

  /// Emits the raw lowercase transcript after each [stop] call (before
  /// bib parsing). Useful for debugging recognition quality.
  Stream<String> get partialResults;

  /// Initialises the recorder and downloads the model if not already cached.
  Future<Result<void>> initialize();

  /// Begins recording audio. No-op if [initialize] has not succeeded.
  Future<void> start();

  /// Stops recording, runs recognition, and emits on [bibNumbers] and
  /// [partialResults].
  Future<void> stop();

  /// Releases all resources. Must be called when the service is no longer
  /// needed.
  Future<void> dispose();
}
