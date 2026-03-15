/// Paths to a downloaded sherpa-onnx model and its supporting assets.
final class ModelAssets {
  const ModelAssets({
    required this.modelDir,
    required this.hotwordsPath,
  });

  /// Directory containing the four ONNX model files and tokens.txt.
  final String modelDir;

  /// Path to the hotwords text file used to bias recognition toward number words.
  final String hotwordsPath;
}
