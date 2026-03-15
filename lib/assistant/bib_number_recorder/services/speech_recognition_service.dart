import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:xceleration/assistant/bib_number_recorder/services/i_speech_recognition_service.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/model_assets.dart';

// ---------------------------------------------------------------------------
// Isolate entry point — must be top-level to be spawnable
// ---------------------------------------------------------------------------

/// Long-lived inference isolate. Loads the model once, then processes
/// transcription requests until a shutdown signal is received.
void _inferenceIsolateEntry(({
  String encoder,
  String decoder,
  String joiner,
  String tokens,
  String hotwordsFile,
  SendPort mainSendPort,
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
  final port = ReceivePort();

  // Signal to the main isolate that the model is loaded and we are ready.
  args.mainSendPort.send(port.sendPort);

  port.listen((message) {
    if (message == null) {
      // Shutdown signal — free resources and exit.
      port.close();
      recognizer.free();
      return;
    }

    // message: ({String wavPath, SendPort replyPort})
    final wavPath = (message as ({String wavPath, SendPort replyPort})).wavPath;
    final replyPort = message.replyPort;

    try {
      final wave = sherpa.readWave(wavPath);
      if (wave.samples.isEmpty) {
        replyPort.send('');
        return;
      }
      final stream = recognizer.createStream();
      try {
        stream.acceptWaveform(
            samples: wave.samples, sampleRate: wave.sampleRate);
        recognizer.decode(stream);
        replyPort.send(
            recognizer.getResult(stream).text.trim().toLowerCase());
      } finally {
        stream.free();
      }
    } catch (_) {
      replyPort.send('');
    }
  });
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// [ISpeechRecognitionService] implementation backed by a long-lived
/// background [Isolate].
///
/// The ONNX model is loaded once in [initialize] and kept resident for the
/// lifetime of the service. Each [transcribe] call sends the WAV path to the
/// isolate and awaits the transcript — no model-reload overhead per call.
class SpeechRecognitionService implements ISpeechRecognitionService {
  SendPort? _sendPort;
  Isolate? _isolate;

  @override
  Future<void> initialize(ModelAssets assets) async {
    final ready = ReceivePort();

    _isolate = await Isolate.spawn(
      _inferenceIsolateEntry,
      (
        encoder: p.join(assets.modelDir, 'encoder-epoch-99-avg-1.int8.onnx'),
        decoder: p.join(assets.modelDir, 'decoder-epoch-99-avg-1.int8.onnx'),
        joiner: p.join(assets.modelDir, 'joiner-epoch-99-avg-1.int8.onnx'),
        tokens: p.join(assets.modelDir, 'tokens.txt'),
        hotwordsFile: assets.hotwordsPath,
        mainSendPort: ready.sendPort,
      ),
    );

    // Wait until the isolate signals it has loaded the model.
    _sendPort = await ready.first as SendPort;
    ready.close();
  }

  @override
  Future<String> transcribe(String wavPath) async {
    if (_sendPort == null) return '';

    final reply = ReceivePort();
    _sendPort!.send((wavPath: wavPath, replyPort: reply.sendPort));
    final result = await reply.first as String;
    reply.close();
    return result;
  }

  @override
  Future<void> dispose() async {
    _sendPort?.send(null); // shutdown signal
    _isolate?.kill(priority: Isolate.immediate);
    _sendPort = null;
    _isolate = null;
  }
}
