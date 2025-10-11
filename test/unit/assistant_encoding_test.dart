import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
import 'package:flutter/material.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

void main() {
  group('Assistant encoding gzip+base64 wrapping', () {
    testWidgets('BibEncodeUtils wraps and BibDecodeUtils unwraps',
        (tester) async {
      final bibs = <BibDatum>[
        BibDatum(bib: '101', name: 'A', teamAbbreviation: 'AW', grade: '12'),
        BibDatum(bib: '55'),
        BibDatum(bib: '102', name: 'B', teamAbbreviation: 'SR', grade: '9'),
        BibDatum(bib: '103', name: 'C', teamAbbreviation: 'AW', grade: '10'),
        BibDatum(bib: '104', name: 'D', teamAbbreviation: 'TL', grade: '10'),
        BibDatum(bib: '105', name: 'E', teamAbbreviation: 'AW', grade: '11'),
        BibDatum(bib: '106', name: 'F', teamAbbreviation: 'TL', grade: '11'),
        BibDatum(bib: '107', name: 'G', teamAbbreviation: 'AW', grade: '12'),
        BibDatum(bib: '108', name: 'H', teamAbbreviation: 'SR', grade: '9'),
        BibDatum(bib: '109', name: 'I', teamAbbreviation: 'AW', grade: '12'),
        BibDatum(bib: '110', name: 'J', teamAbbreviation: 'SR', grade: '9'),
        BibDatum(bib: '111', name: 'K', teamAbbreviation: 'TL', grade: '12'),
        BibDatum(bib: '112', name: 'L', teamAbbreviation: 'AW', grade: '10'),
        BibDatum(bib: '113', name: 'M', teamAbbreviation: 'SR', grade: '9'),
        BibDatum(bib: '114', name: 'N', teamAbbreviation: 'TL', grade: '11'),
        BibDatum(bib: '115', name: 'O', teamAbbreviation: 'TL', grade: '12'),
        BibDatum(bib: '116', name: 'P', teamAbbreviation: 'AW', grade: '10'),
        BibDatum(bib: '117', name: 'Q', teamAbbreviation: 'SR', grade: '9'),
        BibDatum(bib: '118', name: 'R', teamAbbreviation: 'AW', grade: '12'),
        BibDatum(bib: '119', name: 'S', teamAbbreviation: 'AW', grade: '11'),
        BibDatum(bib: '120', name: 'T', teamAbbreviation: 'TL', grade: '9'),
        BibDatum(bib: '121', name: 'U', teamAbbreviation: 'SR', grade: '12'),
        BibDatum(bib: '122', name: 'V', teamAbbreviation: 'SR', grade: '9'),
        BibDatum(bib: '123', name: 'W', teamAbbreviation: 'AW', grade: '11'),
        BibDatum(bib: '124', name: 'X', teamAbbreviation: 'AW', grade: '10'),
        BibDatum(bib: '125', name: 'Y', teamAbbreviation: 'SR', grade: '9'),
        BibDatum(bib: '126', name: 'Z', teamAbbreviation: 'TL', grade: '11'),
      ];

      final encoded = await BibEncodeUtils.getEncodedBibData(bibs);
      // Legacy raw (pre-wrap) format
      final legacyRaw = bibs.map((b) => b.encode()).join(' ');

      // Ensure it looks like base64(gzip(...))
      final decodedBytes = gzip.decode(base64Decode(encoded));
      final raw = utf8.decode(decodedBytes);
      expect(raw.contains('101'), isTrue);
      // Log character lengths for visibility (V2 JSON differs from legacy)
      // ignore: avoid_print
      print(
          '[BIB] legacyRaw.length=${legacyRaw.length} unwrapped.length=${raw.length} encoded.length=${encoded.length}');

      // Legacy-compatible decoder should accept wrapped input
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      final ctx = tester.element(find.byType(SizedBox));
      final decoded = await BibDecodeUtils.decodeEncodedRunners(raw, ctx);
      final decodedWrapped =
          await BibDecodeUtils.decodeEncodedRunners(encoded, ctx);

      expect(decoded?.length, bibs.length);
      expect(decodedWrapped?.length, bibs.length);
    });

    test('TimingEncodeUtils wraps and TimingDecodeUtils unwraps', () async {
      final records = <TimingDatum>[
        TimingDatum(time: '00:18:30.00'),
        TimingDatum(time: '00:18:45.00'),
        TimingDatum(time: '00:18:50.00'),
        TimingDatum(time: '00:18:55.00'),
        TimingDatum(time: '00:19:00.00'),
        TimingDatum(time: '00:19:05.00'),
        TimingDatum(time: '00:19:10.00'),
        TimingDatum(time: '00:19:15.00'),
        TimingDatum(time: '00:19:20.00'),
        TimingDatum(time: '00:19:25.00'),
        TimingDatum(time: '00:19:30.00'),
        TimingDatum(time: '00:19:35.00'),
        TimingDatum(time: '00:19:40.00'),
        TimingDatum(time: '00:19:45.00'),
        TimingDatum(time: '00:19:50.00'),
        TimingDatum(time: '00:19:55.00'),
        TimingDatum(time: '00:20:00.00'),
        TimingDatum(time: '00:20:05.00'),
        TimingDatum(time: '00:20:10.00'),
        TimingDatum(time: '00:20:15.00'),
        TimingDatum(time: '00:20:20.00'),
        TimingDatum(time: '00:20:25.00'),
        TimingDatum(time: '00:20:30.00'),
        TimingDatum(time: '00:20:35.00'),
        TimingDatum(time: '00:20:40.00'),
        TimingDatum(time: '00:20:45.00'),
        TimingDatum(time: '00:20:50.00'),
        TimingDatum(time: '00:20:55.00'),
      ];

      final encoded = await TimingEncodeUtils.encodeTimeRecords(records);
      final legacyRaw = records.map((r) => r.encode()).join(',');

      // Ensure it looks like base64(gzip(...))
      final decodedBytes = gzip.decode(base64Decode(encoded));
      final raw = utf8.decode(decodedBytes);
      expect(raw.split(',').length, records.length);
      // Log character lengths for visibility
      // ignore: avoid_print
      print(
          '[TIMING] legacyRaw.length=${legacyRaw.length} unwrapped.length=${raw.length} encoded.length=${encoded.length}');
      expect(raw, legacyRaw);

      // Legacy-compatible decoder should accept both raw and wrapped
      final decoded = await TimingDecodeUtils.decodeEncodedTimingData(raw);
      final decodedWrapped =
          await TimingDecodeUtils.decodeEncodedTimingData(encoded);

      expect(decoded.length, records.length);
      expect(decodedWrapped.length, records.length);
    });
  });
}
