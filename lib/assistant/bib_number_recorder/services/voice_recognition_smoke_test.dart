// Manual smoke test for VoiceRecognitionService.
//
// Run on a real device (simulator mic is unreliable) with:
//   flutter run -t lib/assistant/bib_number_recorder/services/voice_recognition_smoke_test.dart
//
// On first run the Vosk model (~40 MB) will be downloaded and extracted.
// Subsequent runs use the cached model and start instantly.
//
// Speak a bib number (e.g. "twenty three", "one hundred five") and watch
// logcat / Xcode console for output. Press Ctrl+C to stop.

import 'package:flutter/material.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/voice_recognition_service.dart';
import 'package:xceleration/core/result.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final service = VoiceRecognitionService();

  debugPrint('[Smoke] Initialising VoiceRecognitionService...');
  debugPrint('[Smoke] Downloading Vosk model on first run (~40 MB)...');

  final result = await service.initialize();

  switch (result) {
    case Failure(:final error):
      debugPrint('[Smoke] Initialisation failed: ${error.userMessage}');
      return;
    case Success():
      debugPrint('[Smoke] Model loaded. Starting recognition...');
  }

  service.bibNumbers.listen((bib) {
    if (bib != null) {
      debugPrint('[Smoke] Bib detected: $bib');
    } else {
      debugPrint('[Smoke] Speech detected but not a valid bib number');
    }
  });

  await service.start();
  debugPrint('[Smoke] Listening for 5 minutes. Speak a bib number...');

  // Keep running so the microphone stays active.
  await Future<void>.delayed(const Duration(minutes: 5));

  await service.stop();
  await service.dispose();
  debugPrint('[Smoke] Done.');
}
