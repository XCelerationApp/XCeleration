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

const List<String> _hotwords = [
  'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven',
  'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen',
  'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen', 'twenty',
  'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety',
  'hundred', 'thousand', 'and',
];

/// [IModelDownloadService] implementation that downloads the
/// sherpa-onnx-zipformer-small-en-2023-06-26 model on first use and writes a
/// hotwords file alongside it.
class ModelDownloadService implements IModelDownloadService {
  ModelDownloadService({
    Future<Directory> Function()? supportDirProvider,
    HttpClient Function()? httpClientFactory,
  })  : _supportDirProvider =
            supportDirProvider ?? getApplicationSupportDirectory,
        _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final Future<Directory> Function() _supportDirProvider;
  final HttpClient Function() _httpClientFactory;

  @override
  Future<Result<ModelAssets>> ensureModelReady() async {
    try {
      final modelDir = await _resolveModelDir();
      await _downloadMissingFiles(modelDir);
      final hotwordsPath = await _writeHotwordsFile(modelDir);
      return Success(ModelAssets(modelDir: modelDir, hotwordsPath: hotwordsPath));
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
        await response.pipe(dest.openWrite());
      }
    } finally {
      client.close();
    }
  }

  Future<String> _writeHotwordsFile(String modelDir) async {
    final path = p.join(modelDir, 'hotwords.txt');
    await File(path).writeAsString(_hotwords.join('\n'));
    return path;
  }
}
