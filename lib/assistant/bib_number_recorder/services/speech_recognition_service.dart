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
    maxActivePaths: 8,
    hotwordsFile: args.hotwordsFile,
    hotwordsScore: 10,
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
      final durationSec = wave.samples.isEmpty
          ? 0.0
          : wave.samples.length / wave.sampleRate;
      // ignore: avoid_print — Logger.d is unavailable in isolates.
      print('[SherpaOnnx] WAV loaded: '
          '${wave.samples.length} samples, '
          'rate=${wave.sampleRate} Hz, '
          'duration=${durationSec.toStringAsFixed(2)}s');

      if (wave.samples.isEmpty) {
        // ignore: avoid_print
        print('[SherpaOnnx] Empty WAV — returning blank transcript');
        replyPort.send('');
        return;
      }
      final stream = recognizer.createStream();
      try {
        stream.acceptWaveform(
            samples: wave.samples, sampleRate: wave.sampleRate);
        recognizer.decode(stream);
        final rawResult = recognizer.getResult(stream);
        final transcript = rawResult.text.trim().toLowerCase();
        // ignore: avoid_print
        print('[SherpaOnnx] Raw model text: "${rawResult.text}"');
        // ignore: avoid_print
        print('[SherpaOnnx] Normalised transcript: "$transcript"');
        replyPort.send(transcript);
      } finally {
        stream.free();
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('[SherpaOnnx] Transcription error: $e\n$st');
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
/// The ONNX model is loaded once in [initialize] and kept resident across
/// instances via a static cache. This avoids reloading the ~28 MB model every
/// time the bib recorder screen is revisited. Each [transcribe] call sends
/// the WAV path to the isolate and awaits the transcript.
class SpeechRecognitionService implements ISpeechRecognitionService {
  // Static cache — the send-port survives across instances so the model is
  // loaded only once per app session.
  static SendPort? _cachedSendPort;

  @override
  Future<void> initialize(ModelAssets assets) async {
    // Reuse the existing isolate if one is already running.
    if (_cachedSendPort != null) return;

    final ready = ReceivePort();

    await Isolate.spawn(
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
    _cachedSendPort = await ready.first as SendPort;
    ready.close();
  }

  @override
  Future<String> transcribe(String wavPath) async {
    if (_cachedSendPort == null) return '';

    final reply = ReceivePort();
    _cachedSendPort!.send((wavPath: wavPath, replyPort: reply.sendPort));
    final result = await reply.first as String;
    reply.close();
    return result;
  }

  @override
  Future<void> dispose() async {
    // No-op: the isolate is intentionally kept alive across screen visits.
    // It will be cleaned up when the app process exits.
  }
}
