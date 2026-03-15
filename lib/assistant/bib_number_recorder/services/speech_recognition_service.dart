import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:xceleration/assistant/bib_number_recorder/services/i_speech_recognition_service.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/model_assets.dart';

// ---------------------------------------------------------------------------
// Isolate entry point — must be top-level to be spawnable
// ---------------------------------------------------------------------------

/// Runs sherpa-onnx inference in a background isolate.
/// All parameters are plain strings so the isolate message is sendable.
String _runInferenceInIsolate(({
  String encoder,
  String decoder,
  String joiner,
  String tokens,
  String hotwordsFile,
  String wavPath,
}) args) {
  sherpa.initBindings();

  final config = sherpa.OfflineRecognizerConfig(
    model: sherpa.OfflineModelConfig(
      transducer: sherpa.OfflineTransducerModelConfig(
        encoder: args.encoder,
        decoder: args.decoder,
        joiner: args.joiner,
      ),
      tokens: args.tokens,
      numThreads: 2,
      debug: false,
    ),
    decodingMethod: 'modified_beam_search',
    maxActivePaths: 4,
    hotwordsFile: args.hotwordsFile,
    hotwordsScore: 5,
  );

  final recognizer = sherpa.OfflineRecognizer(config);
  try {
    final wave = sherpa.readWave(args.wavPath);
    if (wave.samples.isEmpty) return '';

    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(
          samples: wave.samples, sampleRate: wave.sampleRate);
      recognizer.decode(stream);
      return recognizer.getResult(stream).text.trim().toLowerCase();
    } finally {
      stream.free();
    }
  } finally {
    recognizer.free();
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// [ISpeechRecognitionService] implementation using sherpa-onnx offline
/// inference in a background [Isolate] to keep the main thread responsive.
class SpeechRecognitionService implements ISpeechRecognitionService {
  const SpeechRecognitionService();

  @override
  Future<String> transcribe(ModelAssets assets, String wavPath) async {
    // Capture plain strings before the closure — the isolate message must only
    // contain sendable values (strings, not objects with platform handles).
    final modelDir = assets.modelDir;
    final hotwordsPath = assets.hotwordsPath;

    return Isolate.run(() => _runInferenceInIsolate((
          encoder: p.join(modelDir, 'encoder-epoch-99-avg-1.int8.onnx'),
          decoder: p.join(modelDir, 'decoder-epoch-99-avg-1.int8.onnx'),
          joiner: p.join(modelDir, 'joiner-epoch-99-avg-1.int8.onnx'),
          tokens: p.join(modelDir, 'tokens.txt'),
          hotwordsFile: hotwordsPath,
          wavPath: wavPath,
        )));
  }
}
