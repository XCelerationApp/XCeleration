import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:xceleration/assistant/bib_number_recorder/services/model_download_service.dart';
import 'package:xceleration/core/result.dart';

// The hotwords that steer voice entry toward number words. Sherpa-ONNX
// splits them with a vocabulary made from the model's tokens.txt; when they
// were written pre-split, none of them loaded.

const _tokens = '<blk> 0\n'
    '<sos/eos> 1\n'
    '<unk> 2\n'
    'S 3\n'
    '▁FO 4\n'
    'UR 5\n'
    '#0 6\n';

void main() {
  group('bpeVocabFromTokens', () {
    test('keeps each piece on the line of its id', () {
      final lines = bpeVocabFromTokens(_tokens).trim().split('\n');

      expect(lines.map((l) => l.split('\t').first),
          ['<blk>', '<sos/eos>', '<unk>', 'S', '▁FO', 'UR', '#0']);
    });

    test('scores every piece the same, and the special ones apart', () {
      final scores = {
        for (final l in bpeVocabFromTokens(_tokens).trim().split('\n'))
          l.split('\t').first: l.split('\t').last,
      };

      expect(scores['▁FO'], '-1');
      expect(scores['UR'], '-1');
      expect(scores['<blk>'], '0');
      expect(scores['#0'], '0');
    });
  });

  test('hotwords are plain upper-case words, as sherpa splits them itself',
      () {
    for (final line in hotwords) {
      expect(line, matches(RegExp(r'^[A-Z]+$')), reason: line);
    }
    expect(hotwords, containsAll(['ZERO', 'NINE', 'HUNDRED']));
  });

  test('writes the vocabulary and hotwords next to the model', () async {
    final support = await Directory.systemTemp.createTemp('model_test');
    addTearDown(() => support.delete(recursive: true));
    final modelDir = Directory(p.join(support.path, 'sherpa_onnx',
        'sherpa-onnx-zipformer-small-en-2023-06-26'))
      ..createSync(recursive: true);
    // Already downloaded, so nothing is fetched.
    for (final f in [
      'encoder-epoch-99-avg-1.int8.onnx',
      'decoder-epoch-99-avg-1.int8.onnx',
      'joiner-epoch-99-avg-1.int8.onnx',
    ]) {
      File(p.join(modelDir.path, f)).writeAsStringSync('');
    }
    File(p.join(modelDir.path, 'tokens.txt')).writeAsStringSync(_tokens);

    final result = await ModelDownloadService(
      supportDirProvider: () async => support,
    ).ensureModelReady();

    final assets = (result as Success).value;
    expect(File(assets.bpeVocabPath).readAsStringSync(),
        bpeVocabFromTokens(_tokens));
    expect(File(assets.hotwordsPath).readAsStringSync(), hotwords.join('\n'));
  });
}
