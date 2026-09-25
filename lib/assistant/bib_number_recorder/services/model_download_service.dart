import 'dart:io';


import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/i_model_download_service.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/model_assets.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';

/// Base URL for model files on Hugging Face.
const String _modelBaseUrl =
    'https://huggingface.co/csukuangfj/'
    'sherpa-onnx-zipformer-small-en-2023-06-26/resolve/main';

const List<String> _requiredModelFiles = [
  'encoder-epoch-99-avg-1.int8.onnx',
  'decoder-epoch-99-avg-1.int8.onnx',
  'joiner-epoch-99-avg-1.int8.onnx',
  'tokens.txt',
];

/// [IModelDownloadService] implementation that downloads the
/// sherpa-onnx-zipformer-small-en-2023-06-26 model on first use.
///
/// There are no hotwords. Written pre-split they never loaded, and as plain
/// words with a vocabulary for sherpa to split them, sherpa's iOS build
/// crashed building that vocabulary (std::bad_alloc) though the Mac build
/// was fine, taking the app down every time the Bib Recorder opened.
class ModelDownloadService implements IModelDownloadService {
  ModelDownloadService({
    Future<Directory> Function()? supportDirProvider,
    HttpClient Function()? httpClientFactory,
  })  : _supportDirProvider =
            supportDirProvider ?? getApplicationSupportDirectory,
        _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final Future<Directory> Function() _supportDirProvider;
  final HttpClient Function() _httpClientFactory;

  /// A download already under way, shared so that fetching the model early
  /// and turning voice on at the same moment do not write the same files
  /// twice over.
  static Future<Result<ModelAssets>>? _inFlight;

  @override
  Future<Result<ModelAssets>> ensureModelReady() {
    return _inFlight ??= _ensureModelReady().whenComplete(() {
      _inFlight = null;
    });
  }

  Future<Result<ModelAssets>> _ensureModelReady() async {
    try {
      final modelDir = await _resolveModelDir();
      await _downloadMissingFiles(modelDir);
      await _removeHotwordFiles(modelDir);
      return Success(ModelAssets(modelDir: modelDir));
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not load speech recognition model.',
        originalException: e,
      ));
    }
  }

  Future<String> _resolveModelDir() async {
    final support = await _supportDirProvider();
    return p.join(
      support.path,
      'sherpa_onnx',
      'sherpa-onnx-zipformer-small-en-2023-06-26',
    );
  }

  Future<void> _downloadMissingFiles(String modelDir) async {
    final allExist = _requiredModelFiles.every(
      (f) => File(p.join(modelDir, f)).existsSync(),
    );
    if (allExist) return;

    await Directory(modelDir).create(recursive: true);
    final client = _httpClientFactory();
    try {
      for (final filename in _requiredModelFiles) {
        final dest = File(p.join(modelDir, filename));
        if (dest.existsSync()) continue;
        final request =
            await client.getUrl(Uri.parse('$_modelBaseUrl/$filename'));
        final response = await request.close();
        if (response.statusCode != 200) {
          throw Exception(
              'Failed to download $filename (HTTP ${response.statusCode})');
        }
        // Written under a temporary name and renamed once whole: a download
        // cut off part way left a short file that looked finished, and voice
        // never worked again on that phone.
        final partial = File('${dest.path}.part');
        await response.pipe(partial.openWrite());
        await partial.rename(dest.path);
      }
    } finally {
      client.close();
    }
  }

  /// Clears out hotword files from earlier versions, which nothing reads now.
  Future<void> _removeHotwordFiles(String modelDir) async {
    for (final name in const ['hotwords.txt', 'bpe.vocab']) {
      final file = File(p.join(modelDir, name));
      if (file.existsSync()) await file.delete();
    }
  }
}
