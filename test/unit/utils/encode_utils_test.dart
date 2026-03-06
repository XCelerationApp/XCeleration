import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

void main() {
  group('compressAndEncode', () {
    test('returns a non-empty string for valid input', () {
      final result = compressAndEncode('hello');

      expect(result, isNotEmpty);
    });

    test('different inputs produce different outputs', () {
      final a = compressAndEncode('hello');
      final b = compressAndEncode('world');

      expect(a, isNot(equals(b)));
    });

    test('same input always produces the same output', () {
      final first = compressAndEncode('test');
      final second = compressAndEncode('test');

      expect(first, equals(second));
    });
  });

  group('TimingEncodeUtils.encodeTimeRecords', () {
    test('encodes an empty list without error', () async {
      final result = await TimingEncodeUtils.encodeTimeRecords([]);

      expect(result, isNotEmpty);
    });

    test('encoded data round-trips correctly for simple times', () async {
      final data = [
        TimingDatum(time: '10.5'),
        TimingDatum(time: '11.2'),
        TimingDatum(time: '12.0'),
      ];

      final encoded = await TimingEncodeUtils.encodeTimeRecords(data);
      final decoded = await TimingDecodeUtils.decodeEncodedTimingData(encoded);

      expect(decoded.length, 3);
      expect(decoded[0].time, '10.5');
      expect(decoded[1].time, '11.2');
      expect(decoded[2].time, '12.0');
    });

    test('encoded data round-trips correctly with conflict records', () async {
      final data = [
        TimingDatum(time: '10.5'),
        TimingDatum(
          time: '11.2',
          conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
        ),
        TimingDatum(time: '12.0'),
      ];

      final encoded = await TimingEncodeUtils.encodeTimeRecords(data);
      final decoded = await TimingDecodeUtils.decodeEncodedTimingData(encoded);

      expect(decoded.length, 3);
      expect(decoded[1].hasConflict, isTrue);
      expect(decoded[1].conflict!.type, ConflictType.missingTime);
      expect(decoded[1].conflict!.offBy, 1);
    });

    test('encodes all conflict types without error', () async {
      final data = [
        TimingDatum(
            time: '1.0',
            conflict: Conflict(type: ConflictType.confirmRunner, offBy: 2)),
        TimingDatum(
            time: '2.0',
            conflict: Conflict(type: ConflictType.missingTime, offBy: 1)),
        TimingDatum(
            time: '3.0',
            conflict: Conflict(type: ConflictType.extraTime, offBy: 1)),
      ];

      final encoded = await TimingEncodeUtils.encodeTimeRecords(data);
      final decoded = await TimingDecodeUtils.decodeEncodedTimingData(encoded);

      expect(decoded[0].conflict!.type, ConflictType.confirmRunner);
      expect(decoded[1].conflict!.type, ConflictType.missingTime);
      expect(decoded[2].conflict!.type, ConflictType.extraTime);
    });
  });

  group('BibEncodeUtils.getEncodedBibData', () {
    test('encodes an empty list without error', () async {
      final result = await BibEncodeUtils.getEncodedBibData([]);

      expect(result, isNotEmpty);
    });

    test('encoded bib data round-trips correctly with full fields', () async {
      final data = [
        BibDatum(
            bib: '101', name: 'Alice', teamAbbreviation: 'EA', grade: '10'),
        BibDatum(bib: '102', name: 'Bob', teamAbbreviation: 'WB', grade: '11'),
      ];

      final encoded = await BibEncodeUtils.getEncodedBibData(data);
      final decoded = await BibDecodeUtils.decodeEncodedRunners(encoded);

      expect(decoded, isA<Success<List<BibDatum>>>());
      final bibs = (decoded as Success<List<BibDatum>>).value;
      expect(bibs.length, 2);
      expect(bibs[0].bib, '101');
      expect(bibs[0].name, 'Alice');
      expect(bibs[0].teamAbbreviation, 'EA');
      expect(bibs[0].grade, '10');
      expect(bibs[1].bib, '102');
    });

    test('deduplicates team abbreviations in encoding', () async {
      final data = [
        BibDatum(
            bib: '101', name: 'Alice', teamAbbreviation: 'EA', grade: '10'),
        BibDatum(bib: '102', name: 'Bob', teamAbbreviation: 'EA', grade: '11'),
        BibDatum(bib: '103', name: 'Carol', teamAbbreviation: 'WB', grade: '9'),
      ];

      final encoded = await BibEncodeUtils.getEncodedBibData(data);
      final decoded = await BibDecodeUtils.decodeEncodedRunners(encoded);

      expect(decoded, isA<Success<List<BibDatum>>>());
      final bibs = (decoded as Success<List<BibDatum>>).value;
      expect(bibs[0].teamAbbreviation, 'EA');
      expect(bibs[1].teamAbbreviation, 'EA');
      expect(bibs[2].teamAbbreviation, 'WB');
    });

    test('same input always produces the same encoded output', () async {
      final data = [
        BibDatum(
            bib: '101', name: 'Alice', teamAbbreviation: 'EA', grade: '10'),
      ];

      final first = await BibEncodeUtils.getEncodedBibData(data);
      final second = await BibEncodeUtils.getEncodedBibData(data);

      expect(first, equals(second));
    });
  });
}
