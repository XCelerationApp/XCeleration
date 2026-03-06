import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

/// Round-trip encode/decode tests covering the coach workflow:
/// timing data is encoded by the assistant device and decoded on the coach side.
void main() {
  group('TimingEncodeUtils + TimingDecodeUtils round-trip', () {
    test('simple runner times survive encode → decode', () async {
      final original = [
        TimingDatum(time: '1:01.5'),
        TimingDatum(time: '1:02.3'),
        TimingDatum(time: '1:03.1'),
      ];

      final encoded = await TimingEncodeUtils.encodeTimeRecords(original);
      final decoded = await TimingDecodeUtils.decodeEncodedTimingData(encoded);

      expect(decoded.length, 3);
      expect(decoded[0].time, '1:01.5');
      expect(decoded[1].time, '1:02.3');
      expect(decoded[2].time, '1:03.1');
      for (final datum in decoded) {
        expect(datum.hasConflict, isFalse);
      }
    });

    test('extraTime conflict survives encode → decode', () async {
      final original = [
        TimingDatum(time: '1:01.5'),
        TimingDatum(time: '1:02.3'),
        TimingDatum(
          time: '1:02.3',
          conflict: Conflict(type: ConflictType.extraTime, offBy: 1),
        ),
      ];

      final encoded = await TimingEncodeUtils.encodeTimeRecords(original);
      final decoded = await TimingDecodeUtils.decodeEncodedTimingData(encoded);

      expect(decoded.length, 3);
      expect(decoded[2].conflict!.type, ConflictType.extraTime);
      expect(decoded[2].conflict!.offBy, 1);
    });

    test('missingTime conflict survives encode → decode', () async {
      final original = [
        TimingDatum(time: '1:01.5'),
        TimingDatum(
          time: 'TBD',
          conflict: Conflict(type: ConflictType.missingTime, offBy: 2),
        ),
      ];

      final encoded = await TimingEncodeUtils.encodeTimeRecords(original);
      final decoded = await TimingDecodeUtils.decodeEncodedTimingData(encoded);

      expect(decoded.length, 2);
      expect(decoded[1].conflict!.type, ConflictType.missingTime);
      expect(decoded[1].conflict!.offBy, 2);
    });

    test('confirmRunner conflict survives encode → decode', () async {
      final original = [
        TimingDatum(time: '1:01.5'),
        TimingDatum(time: '1:02.3'),
        TimingDatum(
          time: '1:02.3',
          conflict: Conflict(type: ConflictType.confirmRunner, offBy: 2),
        ),
      ];

      final encoded = await TimingEncodeUtils.encodeTimeRecords(original);
      final decoded = await TimingDecodeUtils.decodeEncodedTimingData(encoded);

      expect(decoded.length, 3);
      expect(decoded[2].conflict!.type, ConflictType.confirmRunner);
    });

    test('empty timing list encodes and decodes to empty list', () async {
      final encoded = await TimingEncodeUtils.encodeTimeRecords([]);
      final decoded = await TimingDecodeUtils.decodeEncodedTimingData(encoded);

      expect(decoded, isEmpty);
    });
  });

  group('BibEncodeUtils + BibDecodeUtils round-trip', () {
    test('bib data with full runner info survives encode → decode', () async {
      final original = [
        BibDatum(bib: '101', name: 'Alice', teamAbbreviation: 'EA', grade: '10'),
        BibDatum(bib: '102', name: 'Bob', teamAbbreviation: 'WB', grade: '11'),
        BibDatum(bib: '103', name: 'Carol', teamAbbreviation: 'EA', grade: '9'),
      ];

      final encoded = await BibEncodeUtils.getEncodedBibData(original);
      final decoded = await BibDecodeUtils.decodeEncodedRunners(encoded);

      expect(decoded, isA<Success<List<BibDatum>>>());
      final bibs = (decoded as Success<List<BibDatum>>).value;
      expect(bibs.length, 3);
      expect(bibs[0].bib, '101');
      expect(bibs[0].name, 'Alice');
      expect(bibs[0].teamAbbreviation, 'EA');
      expect(bibs[0].grade, '10');
      expect(bibs[1].bib, '102');
      expect(bibs[1].teamAbbreviation, 'WB');
    });

    test('bib data with special characters in names survives encode → decode',
        () async {
      final original = [
        BibDatum(
            bib: '101',
            name: "O'Brien",
            teamAbbreviation: 'EA',
            grade: '10'),
      ];

      final encoded = await BibEncodeUtils.getEncodedBibData(original);
      final decoded = await BibDecodeUtils.decodeEncodedRunners(encoded);

      expect(decoded, isA<Success<List<BibDatum>>>());
      final bibs = (decoded as Success<List<BibDatum>>).value;
      expect(bibs[0].name, "O'Brien");
    });

    test('empty bib list encodes and decodes to empty list', () async {
      final encoded = await BibEncodeUtils.getEncodedBibData([]);
      final decoded = await BibDecodeUtils.decodeEncodedRunners(encoded);

      expect(decoded, isA<Success<List<BibDatum>>>());
      final bibs = (decoded as Success<List<BibDatum>>).value;
      expect(bibs, isEmpty);
    });
  });
}
