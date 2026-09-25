import 'package:xceleration/assistant/bib_number_recorder/services/model_assets.dart';
import 'package:xceleration/core/result.dart';

/// Downloads and caches the sherpa-onnx model files required for offline
/// speech recognition.
abstract interface class IModelDownloadService {
  /// Ensures all model files are present on disk, downloading them on first
  /// use (~28 MB). Returns a [ModelAssets] with the resolved paths.
  Future<Result<ModelAssets>> ensureModelReady();
}
