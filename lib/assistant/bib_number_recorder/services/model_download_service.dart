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

/// Hotwords pre-tokenized into BPE subwords matching the model's tokens.txt.
///
/// The model vocabulary uses UPPERCASE tokens with ▁ (U+2581) as the
/// word-boundary prefix. Each line in the generated hotwords.txt must contain
/// space-separated tokens that exist verbatim in tokens.txt; Sherpa ONNX looks
/// them up directly — it does NOT re-tokenize plain text.
///
/// Tokens verified against:
///   huggingface.co/csukuangfj/sherpa-onnx-zipformer-small-en-2023-06-26/…/tokens.txt
/// U+2581 LOWER ONE EIGHTH BLOCK — the word-boundary marker in the model's
/// BPE vocabulary.  Using the explicit escape avoids copy-paste encoding issues.
const String _ws = '\u2581';

const List<String> _hotwordsBpe = [
  // Single-token words
  '${_ws}ONE',                  // 126
  '${_ws}TWO',                  // 287
  '${_ws}THREE',                // 405
  '${_ws}SIX',                  // 481
  '${_ws}HUNDRED',              // 487
  '${_ws}AND',                  // 7

  // Two–four token words
  '$_ws Z ER O :10.0',          // ZERO [34 234 29 24] — extra boost
  '${_ws}FO UR',                // FOUR  [312 79]
  '${_ws}FI VE',                // FIVE  [147 75]
  '${_ws}SE VE N',              // SEVEN [125 75 13]
  '${_ws}E IGHT',               // EIGHT [54 179]
  '${_ws}NI NE',                // NINE  [436 88]
  '${_ws}T EN',                 // TEN   [56 72]
  '${_ws}E LE VE N',            // ELEVEN  [54 44 75 13]
  '${_ws}T W EL VE',            // TWELVE  [56 65 131 75]

  // Teens — TE (114) not T+E; EIGHTEEN is the exception (E after IGHT)
  '${_ws}TH IR TE EN',          // THIRTEEN  [119 97 114 72]
  '${_ws}FO UR TE EN',          // FOURTEEN  [312 79 114 72]
  '${_ws}FI F TE EN',           // FIFTEEN   [147 38 114 72]
  '${_ws}SIX TE EN',            // SIXTEEN   [481 114 72]
  '${_ws}SE VE N TE EN',        // SEVENTEEN [125 75 13 114 72]
  '${_ws}E IGHT E EN',          // EIGHTEEN  [54 179 11 72]
  '${_ws}NI NE TE EN',          // NINETEEN  [436 88 114 72]

  // Tens — TWENTY: ENT(96)+Y(16); FORTY: FOR(42)+TY(240)
  '${_ws}T W ENT Y',            // TWENTY  [56 65 96 16]
  '${_ws}TH IR TY',             // THIRTY  [119 97 240]
  '${_ws}FOR TY',               // FORTY   [42 240]
  '${_ws}FI F TY',              // FIFTY   [147 38 240]
  '${_ws}SIX TY',               // SIXTY   [481 240]
  '${_ws}SE VE N TY',           // SEVENTY [125 75 13 240]
  '${_ws}E IGHT Y',             // EIGHTY  [54 179 16]
  '${_ws}NI NE TY',             // NINETY  [436 88 240]

  // THOUSAND — AN(143)+D(12), not A+ND
  '${_ws}TH OUS AN D',          // THOUSAND [119 281 143 12]
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
    final file = File(path);
    final expected = _hotwordsBpe.join('\n');
    if (file.existsSync() && await file.readAsString() == expected) {
      return path;
    }
    await file.writeAsString(expected);
    return path;
  }
}
