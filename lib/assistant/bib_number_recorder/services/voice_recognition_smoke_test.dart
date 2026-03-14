// Manual smoke test for VoiceRecognitionService.
//
// Run on a real device (simulator mic is unreliable with Vosk) with:
//   flutter run -t lib/assistant/bib_number_recorder/services/voice_recognition_smoke_test.dart
//
// On first run the Vosk model (~40 MB) will be downloaded and extracted.
// Subsequent runs use the cached model and start instantly.
//
// Hold the button to speak a bib number, release to recognise.

import 'package:flutter/material.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/voice_recognition_test_screen.dart';

void main() {
  runApp(const _SmokeTestApp());
}

class _SmokeTestApp extends StatelessWidget {
  const _SmokeTestApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VoiceRecognitionTestScreen(),
    );
  }
}
