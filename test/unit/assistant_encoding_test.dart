import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/core/utils/enums.dart';

void main() {
  group('Assistant encoding gzip+base64 wrapping', () {
    test('BibEncodeUtils wraps and BibDecodeUtils unwraps', () async {
      final bibs = <BibDatum>[
        BibDatum(
            bib: '1001',
            name: 'Alexander Johnson',
            teamAbbreviation: 'AW',
            grade: '12'),
        BibDatum(
            bib: '1002',
            name: 'Emma Williams',
            teamAbbreviation: 'SR',
            grade: '11'),
        BibDatum(
            bib: '1003',
            name: 'Michael Brown',
            teamAbbreviation: 'TL',
            grade: '10'),
        BibDatum(
            bib: '1004',
            name: 'Sophia Davis',
            teamAbbreviation: 'AW',
            grade: '9'),
        BibDatum(
            bib: '1005',
            name: 'James Miller',
            teamAbbreviation: 'SR',
            grade: '12'),
        BibDatum(
            bib: '1006',
            name: 'Olivia Wilson',
            teamAbbreviation: 'TL',
            grade: '11'),
        BibDatum(
            bib: '1007',
            name: 'Benjamin Moore',
            teamAbbreviation: 'AW',
            grade: '10'),
        BibDatum(
            bib: '1008',
            name: 'Isabella Taylor',
            teamAbbreviation: 'SR',
            grade: '9'),
        BibDatum(
            bib: '1009',
            name: 'William Anderson',
            teamAbbreviation: 'TL',
            grade: '12'),
        BibDatum(
            bib: '1010',
            name: 'Charlotte Thomas',
            teamAbbreviation: 'AW',
            grade: '11'),
        BibDatum(
            bib: '1011',
            name: 'Lucas Jackson',
            teamAbbreviation: 'SR',
            grade: '10'),
        BibDatum(
            bib: '1012',
            name: 'Amelia White',
            teamAbbreviation: 'TL',
            grade: '9'),
        BibDatum(
            bib: '1013',
            name: 'Henry Harris',
            teamAbbreviation: 'AW',
            grade: '12'),
        BibDatum(
            bib: '1014',
            name: 'Mia Martin',
            teamAbbreviation: 'SR',
            grade: '11'),
        BibDatum(
            bib: '1015',
            name: 'Owen Thompson',
            teamAbbreviation: 'TL',
            grade: '10'),
        BibDatum(
            bib: '1016',
            name: 'Harper Garcia',
            teamAbbreviation: 'AW',
            grade: '9'),
        BibDatum(
            bib: '1017',
            name: 'Elijah Martinez',
            teamAbbreviation: 'SR',
            grade: '12'),
        BibDatum(
            bib: '1018',
            name: 'Evelyn Robinson',
            teamAbbreviation: 'TL',
            grade: '11'),
        BibDatum(
            bib: '1019',
            name: 'Sebastian Clark',
            teamAbbreviation: 'AW',
            grade: '10'),
        BibDatum(
            bib: '1020',
            name: 'Abigail Rodriguez',
            teamAbbreviation: 'SR',
            grade: '9'),
        BibDatum(
            bib: '1021',
            name: 'Jack Lewis',
            teamAbbreviation: 'TL',
            grade: '12'),
        BibDatum(
            bib: '1022',
            name: 'Emily Lee',
            teamAbbreviation: 'AW',
            grade: '11'),
        BibDatum(
            bib: '1023',
            name: 'Aiden Walker',
            teamAbbreviation: 'SR',
            grade: '10'),
        BibDatum(
            bib: '1024',
            name: 'Elizabeth Hall',
            teamAbbreviation: 'TL',
            grade: '9'),
        BibDatum(
            bib: '1025',
            name: 'Matthew Allen',
            teamAbbreviation: 'AW',
            grade: '12'),
        BibDatum(
            bib: '1026',
            name: 'Sofia Young',
            teamAbbreviation: 'SR',
            grade: '11'),
        BibDatum(
            bib: '1027',
            name: 'Daniel Hernandez',
            teamAbbreviation: 'TL',
            grade: '10'),
        BibDatum(
            bib: '1028',
            name: 'Avery King',
            teamAbbreviation: 'AW',
            grade: '9'),
        BibDatum(
            bib: '1029',
            name: 'Joseph Wright',
            teamAbbreviation: 'SR',
            grade: '12'),
        BibDatum(
            bib: '1030',
            name: 'Ella Lopez',
            teamAbbreviation: 'TL',
            grade: '11'),
        BibDatum(
            bib: '1031',
            name: 'Samuel Hill',
            teamAbbreviation: 'AW',
            grade: '10'),
        BibDatum(
            bib: '1032',
            name: 'Scarlett Scott',
            teamAbbreviation: 'SR',
            grade: '9'),
        BibDatum(
            bib: '1033',
            name: 'David Green',
            teamAbbreviation: 'TL',
            grade: '12'),
        BibDatum(
            bib: '1034',
            name: 'Victoria Adams',
            teamAbbreviation: 'AW',
            grade: '11'),
        BibDatum(
            bib: '1035',
            name: 'Carter Baker',
            teamAbbreviation: 'SR',
            grade: '10'),
        BibDatum(
            bib: '1036',
            name: 'Grace Gonzalez',
            teamAbbreviation: 'TL',
            grade: '9'),
        BibDatum(
            bib: '1037',
            name: 'Wyatt Nelson',
            teamAbbreviation: 'AW',
            grade: '12'),
        BibDatum(
            bib: '1038',
            name: 'Chloe Carter',
            teamAbbreviation: 'SR',
            grade: '11'),
        BibDatum(
            bib: '1039',
            name: 'John Mitchell',
            teamAbbreviation: 'TL',
            grade: '10'),
        BibDatum(
            bib: '1040',
            name: 'Zoey Perez',
            teamAbbreviation: 'AW',
            grade: '9'),
        BibDatum(
            bib: '1041',
            name: 'Luke Roberts',
            teamAbbreviation: 'SR',
            grade: '12'),
        BibDatum(
            bib: '1042',
            name: 'Lily Turner',
            teamAbbreviation: 'TL',
            grade: '11'),
        BibDatum(
            bib: '1043',
            name: 'Isaac Phillips',
            teamAbbreviation: 'AW',
            grade: '10'),
        BibDatum(
            bib: '1044',
            name: 'Layla Campbell',
            teamAbbreviation: 'SR',
            grade: '9'),
        BibDatum(
            bib: '1045',
            name: 'Ryan Parker',
            teamAbbreviation: 'TL',
            grade: '12'),
        BibDatum(
            bib: '1046',
            name: 'Zoe Evans',
            teamAbbreviation: 'AW',
            grade: '11'),
        BibDatum(
            bib: '1047',
            name: 'Nathan Edwards',
            teamAbbreviation: 'SR',
            grade: '10'),
        BibDatum(
            bib: '1048',
            name: 'Nora Collins',
            teamAbbreviation: 'TL',
            grade: '9'),
        BibDatum(
            bib: '1049',
            name: 'Caleb Stewart',
            teamAbbreviation: 'AW',
            grade: '12'),
        BibDatum(
            bib: '1050',
            name: 'Hannah Sanchez',
            teamAbbreviation: 'SR',
            grade: '11'),
        BibDatum(
            bib: '1051',
            name: 'Hunter Morris',
            teamAbbreviation: 'TL',
            grade: '10'),
        BibDatum(
            bib: '1052',
            name: 'Addison Rogers',
            teamAbbreviation: 'AW',
            grade: '9'),
        BibDatum(
            bib: '1053',
            name: 'Christian Reed',
            teamAbbreviation: 'SR',
            grade: '12'),
        BibDatum(
            bib: '1054',
            name: 'Aubrey Cook',
            teamAbbreviation: 'TL',
            grade: '11'),
        BibDatum(
            bib: '1055',
            name: 'Connor Morgan',
            teamAbbreviation: 'AW',
            grade: '10'),
        BibDatum(
            bib: '1056',
            name: 'Brooklyn Bell',
            teamAbbreviation: 'SR',
            grade: '9'),
        BibDatum(
            bib: '1057',
            name: 'Aaron Murphy',
            teamAbbreviation: 'TL',
            grade: '12'),
        BibDatum(
            bib: '1058',
            name: 'Leah Bailey',
            teamAbbreviation: 'AW',
            grade: '11'),
        BibDatum(
            bib: '1059',
            name: 'Ian Rivera',
            teamAbbreviation: 'SR',
            grade: '10'),
        BibDatum(
            bib: '1060',
            name: 'Savannah Cooper',
            teamAbbreviation: 'TL',
            grade: '9'),
        BibDatum(
            bib: '1061',
            name: 'Jeremiah Richardson',
            teamAbbreviation: 'AW',
            grade: '12'),
        BibDatum(
            bib: '1062', name: 'Anna Cox', teamAbbreviation: 'SR', grade: '11'),
        BibDatum(
            bib: '1063',
            name: 'Jordan Howard',
            teamAbbreviation: 'TL',
            grade: '10'),
        BibDatum(
            bib: '1064',
            name: 'Allison Ward',
            teamAbbreviation: 'AW',
            grade: '9'),
        BibDatum(
            bib: '1065',
            name: 'Cameron Torres',
            teamAbbreviation: 'SR',
            grade: '12'),
        BibDatum(
            bib: '1066',
            name: 'Audrey Peterson',
            teamAbbreviation: 'TL',
            grade: '11'),
        BibDatum(
            bib: '1067',
            name: 'Adrian Gray',
            teamAbbreviation: 'AW',
            grade: '10'),
        BibDatum(
            bib: '1068',
            name: 'Skylar Ramirez',
            teamAbbreviation: 'SR',
            grade: '9'),
        BibDatum(
            bib: '1069',
            name: 'Brayden James',
            teamAbbreviation: 'TL',
            grade: '12'),
        BibDatum(
            bib: '1070',
            name: 'Bella Watson',
            teamAbbreviation: 'AW',
            grade: '11'),
        BibDatum(
            bib: '1071',
            name: 'Grayson Brooks',
            teamAbbreviation: 'SR',
            grade: '10'),
        BibDatum(
            bib: '1072',
            name: 'Claire Kelly',
            teamAbbreviation: 'TL',
            grade: '9'),
        BibDatum(
            bib: '1073',
            name: 'Landon Sanders',
            teamAbbreviation: 'AW',
            grade: '12'),
        BibDatum(
            bib: '1074',
            name: 'Samantha Price',
            teamAbbreviation: 'SR',
            grade: '11'),
        BibDatum(
            bib: '1075',
            name: 'Mason Bennett',
            teamAbbreviation: 'TL',
            grade: '10'),
        BibDatum(
            bib: '1076',
            name: 'Natalie Wood',
            teamAbbreviation: 'AW',
            grade: '9'),
        BibDatum(
            bib: '1077',
            name: 'Colton Barnes',
            teamAbbreviation: 'SR',
            grade: '12'),
        BibDatum(
            bib: '1078',
            name: 'Maya Ross',
            teamAbbreviation: 'TL',
            grade: '11'),
        BibDatum(
            bib: '1079',
            name: 'Jose Henderson',
            teamAbbreviation: 'AW',
            grade: '10'),
        BibDatum(
            bib: '1080',
            name: 'Kennedy Coleman',
            teamAbbreviation: 'SR',
            grade: '9'),
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
      final decoded = await BibDecodeUtils.decodeEncodedRunners(raw);
      final decodedWrapped = await BibDecodeUtils.decodeEncodedRunners(encoded);

      expect(
          switch (decoded) { Success(:final value) => value.length, _ => -1 },
          bibs.length);
      expect(
          switch (decodedWrapped) {
            Success(:final value) => value.length,
            _ => -1
          },
          bibs.length);
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
        TimingDatum(time: '00:21:00.00'),
        TimingDatum(time: '00:21:05.00'),
        TimingDatum(time: '00:21:10.00'),
        TimingDatum(time: '00:21:15.00'),
        TimingDatum(time: '00:21:20.00'),
        TimingDatum(time: '00:21:25.00'),
        TimingDatum(time: '00:21:30.00'),
        TimingDatum(time: '00:21:35.00'),
        TimingDatum(time: '00:21:40.00'),
        TimingDatum(time: '00:21:45.00'),
        TimingDatum(time: '00:21:50.00'),
        TimingDatum(time: '00:21:55.00'),
        TimingDatum(time: '00:22:00.00'),
        TimingDatum(time: '00:22:05.00'),
        TimingDatum(time: '00:22:10.00'),
        TimingDatum(time: '00:22:15.00'),
        TimingDatum(time: '00:22:20.00'),
        TimingDatum(time: '00:22:25.00'),
        TimingDatum(time: '00:22:30.00'),
        TimingDatum(time: '00:22:35.00'),
        TimingDatum(time: '00:22:40.00'),
        TimingDatum(time: '00:22:45.00'),
        TimingDatum(
            time: '00:22:50.00',
            conflict: Conflict(type: ConflictType.confirmRunner)),
        TimingDatum(time: '00:22:55.00'),
        TimingDatum(time: '00:23:00.00'),
        TimingDatum(time: '00:23:05.00'),
        TimingDatum(time: '00:23:10.00'),
        TimingDatum(
            time: '00:23:15.00',
            conflict: Conflict(type: ConflictType.confirmRunner)),
        TimingDatum(time: '00:23:20.00'),
        TimingDatum(time: '00:23:25.00'),
        TimingDatum(time: '00:23:30.00'),
        TimingDatum(time: '00:23:35.00'),
        TimingDatum(time: '00:23:40.00'),
        TimingDatum(time: '00:23:45.00'),
        TimingDatum(time: '00:23:50.00'),
        TimingDatum(time: '00:23:55.00'),
        TimingDatum(time: '00:24:00.00'),
        TimingDatum(time: '00:24:05.00'),
        TimingDatum(time: '00:24:10.00'),
        TimingDatum(time: '00:24:15.00'),
        TimingDatum(time: '00:24:20.00'),
        TimingDatum(time: '00:24:25.00'),
        TimingDatum(
            time: '00:24:30.00',
            conflict: Conflict(type: ConflictType.confirmRunner)),
        TimingDatum(time: '00:24:35.00'),
        TimingDatum(time: '00:24:40.00'),
        TimingDatum(time: '00:24:45.00'),
        TimingDatum(time: '00:24:50.00'),
        TimingDatum(time: '00:24:55.00'),
        TimingDatum(time: '00:25:00.00'),
        TimingDatum(time: '00:25:05.00'),
        TimingDatum(time: '00:25:10.00'),
        TimingDatum(time: '00:25:15.00'),
        TimingDatum(time: '00:25:20.00'),
        TimingDatum(time: '00:25:25.00'),
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
