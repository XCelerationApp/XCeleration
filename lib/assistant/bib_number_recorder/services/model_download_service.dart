import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

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

/// Number words to bias recognition toward, one per line, in the model's
/// upper case. Sherpa-ONNX splits them into the model's word pieces itself,
/// using the vocabulary written by [bpeVocabFromTokens].
///
/// These used to be written out pre-split ("▁FO UR"), but sherpa reads a
/// hotwords file one character at a time for anything outside ASCII, so the
/// ▁ was cut off every word and the whole list failed to load.
@visibleForTesting
const List<String> hotwords = [
  'ZERO', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT',
  'NINE', 'TEN', 'ELEVEN', 'TWELVE', 'THIRTEEN', 'FOURTEEN', 'FIFTEEN', 'SIXTEEN',
  'SEVENTEEN', 'EIGHTEEN', 'NINETEEN',
  'TWENTY', 'THIRTY', 'FORTY', 'FIFTY', 'SIXTY', 'SEVENTY', 'EIGHTY',
  'NINETY',
  'HUNDRED', 'THOUSAND', 'AND',
];

/// A sentencepiece vocabulary for the model, made from its tokens.txt,
/// which sherpa-onnx needs to split [hotwords] into word pieces. The model
/// does not ship one.
///
/// Lines keep tokens.txt's order, so a piece's line is its id. Every piece
/// scores the same, so sherpa picks the split with the fewest pieces, longest
/// first: for every word in [hotwords] that is the split the model itself
/// uses ("FOUR" is ▁FO UR, "THOUSAND" is ▁TH OUS AN D).
@visibleForTesting
String bpeVocabFromTokens(String tokensTxt) {
  final out = StringBuffer();
  for (final line in const LineSplitter().convert(tokensTxt)) {
    if (line.trim().isEmpty) continue;
    final token = line.substring(0, line.lastIndexOf(' '));
    // <blk>, <unk> and the like never appear in text.
    final special = token.startsWith('<') || token.startsWith('#');
    out.writeln('$token\t${special ? 0 : -1}');
  }
  return out.toString();
}

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
      final bpeVocabPath = await _writeBpeVocab(modelDir);
      final hotwordsPath = await _writeHotwordsFile(modelDir);
      return Success(ModelAssets(
        modelDir: modelDir,
        hotwordsPath: hotwordsPath,
        bpeVocabPath: bpeVocabPath,
      ));
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

  Future<String> _writeHotwordsFile(String modelDir) =>
      _writeIfChanged(p.join(modelDir, 'hotwords.txt'), hotwords.join('\n'));

  Future<String> _writeBpeVocab(String modelDir) async {
    final tokens =
        await File(p.join(modelDir, 'tokens.txt')).readAsString();
    return _writeIfChanged(
        p.join(modelDir, 'bpe.vocab'), bpeVocabFromTokens(tokens));
  }

  Future<String> _writeIfChanged(String path, String contents) async {
    final file = File(path);
    if (file.existsSync() && await file.readAsString() == contents) {
      return path;
    }
    await file.writeAsString(contents);
    return path;
  }
}
