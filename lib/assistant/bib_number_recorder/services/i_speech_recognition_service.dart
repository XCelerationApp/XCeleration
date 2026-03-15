import 'package:xceleration/assistant/bib_number_recorder/services/model_assets.dart';

/// Manages an offline speech recognition engine.
///
/// Lifecycle: [initialize] → [transcribe] (repeatable) → [dispose].
abstract interface class ISpeechRecognitionService {
  /// Loads the sherpa-onnx model described by [assets] into a background
  /// isolate. The model stays resident until [dispose] is called, so
  /// subsequent [transcribe] calls pay no model-load overhead.
  Future<void> initialize(ModelAssets assets);

  /// Transcribes the WAV file at [wavPath] and returns the raw lowercase
  /// transcript, or an empty string if no speech was detected.
  ///
  /// [initialize] must be called before the first [transcribe].
  Future<String> transcribe(String wavPath);

  /// Shuts down the background isolate and releases all model resources.
  Future<void> dispose();
}
