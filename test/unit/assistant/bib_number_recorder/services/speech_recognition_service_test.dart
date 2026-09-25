import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/speech_recognition_service.dart';

// A quick tap of the mic button records a few hundredths of a second, and
// the speech model aborts the app on a clip under about 0.08 s.

void main() {
  test('a tap-length clip is not transcribed', () {
    expect(tooShortToTranscribe(1051, 16000), isTrue); // the 0.07 s that crashed
    expect(tooShortToTranscribe(0, 16000), isTrue);
  });

  test('a clip long enough to say a bib is', () {
    expect(tooShortToTranscribe(4000, 16000), isFalse); // a quarter second
    expect(tooShortToTranscribe(27226, 16000), isFalse);
  });

  test('a broken file with no sample rate is not transcribed', () {
    expect(tooShortToTranscribe(16000, 0), isTrue);
  });
}
