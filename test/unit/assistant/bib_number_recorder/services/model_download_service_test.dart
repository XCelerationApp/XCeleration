import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:xceleration/assistant/bib_number_recorder/services/model_download_service.dart';
import 'package:xceleration/core/result.dart';

// The speech model for voice entry, fetched once and kept on the phone.

void main() {
  late Directory support;
  late Directory modelDir;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('model_test');
    modelDir = Directory(p.join(support.path, 'sherpa_onnx',
        'sherpa-onnx-zipformer-small-en-2023-06-26'))
      ..createSync(recursive: true);
    // Already downloaded, so nothing is fetched.
    for (final f in [
      'encoder-epoch-99-avg-1.int8.onnx',
      'decoder-epoch-99-avg-1.int8.onnx',
      'joiner-epoch-99-avg-1.int8.onnx',
      'tokens.txt',
    ]) {
      File(p.join(modelDir.path, f)).writeAsStringSync('');
    }
  });

  tearDown(() => support.delete(recursive: true));

  ModelDownloadService service() =>
      ModelDownloadService(supportDirProvider: () async => support);

  test('finds a model already on the phone', () async {
    final result = await service().ensureModelReady();

    expect((result as Success).value.modelDir, modelDir.path);
  });

  test('clears out hotword files an earlier version left', () async {
    // Loading these crashed sherpa's iOS build.
    for (final f in ['hotwords.txt', 'bpe.vocab']) {
      File(p.join(modelDir.path, f)).writeAsStringSync('x');
    }

    await service().ensureModelReady();

    expect(File(p.join(modelDir.path, 'hotwords.txt')).existsSync(), isFalse);
    expect(File(p.join(modelDir.path, 'bpe.vocab')).existsSync(), isFalse);
  });

  test('a fetch already under way is shared, not started twice', () async {
    // Fetched early as the Bib Recorder opens, and again as voice turns on.
    final first = service().ensureModelReady();
    final second = service().ensureModelReady();

    expect(identical(first, second), isTrue);
    await first;
  });
}
