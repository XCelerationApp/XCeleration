import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/decode_utils.dart';

void main() {
  group('BibDecodeUtils.decodeEncodedRunners', () {
    test('fails on a malformed row instead of skipping it', () async {
      // Bibs line up with times by position, so a skipped row shifts every
      // later bib onto the wrong time.
      final result = await BibDecodeUtils.decodeEncodedRunners(
          '{"teams":[],"r":[["1","A",null,"11"],["2"],["3","C",null,"10"]]}');

      expect(result, isA<Failure>());
    });

    test('decodes well-formed rows in order', () async {
      final result = await BibDecodeUtils.decodeEncodedRunners(
          '{"teams":["EAG"],"r":[["1","A",0,"11"],["2","B",0,"10"]]}');

      expect([for (final b in (result as Success).value) b.bib], ['1', '2']);
    });
  });

  group('TimingDecodeUtils.decodeEncodedTimingData', () {
    test('strict mode throws on an unreadable entry', () async {
      await expectLater(
        TimingDecodeUtils.decodeEncodedTimingData('10:00.0,1O:05.0',
            strict: true),
        throwsFormatException,
      );
    });

    test('lenient mode still drops unreadable entries for local reads',
        () async {
      final data =
          await TimingDecodeUtils.decodeEncodedTimingData('10:00.0,1O:05.0');

      expect(data.map((d) => d.time), ['10:00.0']);
    });
  });
}
