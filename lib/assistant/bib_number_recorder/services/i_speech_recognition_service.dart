import 'package:xceleration/assistant/bib_number_recorder/services/model_assets.dart';

/// Runs offline speech inference against a WAV file and returns the raw
/// lower-cased transcript.
abstract interface class ISpeechRecognitionService {
  /// Transcribes [wavPath] using the sherpa-onnx model described by [assets].
  ///
  /// Returns the raw lowercase transcript, or an empty string if no speech was
  /// detected. Never throws — callers should handle the empty-string case.
  Future<String> transcribe(ModelAssets assets, String wavPath);
}
