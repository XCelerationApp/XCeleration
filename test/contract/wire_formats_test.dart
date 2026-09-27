import 'dart:convert';
import 'dart:io';

import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/assistant/race_timer/controller/timing_controller.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/services/assistant_storage_service.dart';
import 'package:xceleration/core/connection/controller/qr_connection_controller.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/services/haptic_feedback_service.dart';
import 'package:xceleration/core/utils/barcode_scanner_interface.dart';
import 'package:xceleration/core/utils/connection_utils.dart';
import 'package:xceleration/core/utils/data_package.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/platform_checker.dart';
import 'package:xceleration/core/utils/race_share_decoder.dart';

import 'wire_samples.dart';

// Everything one phone sends another is a contract: coaches and volunteers
// do not all update at once, so today's app must read what every earlier
// release sent, and must not change what it sends by accident. Each
// release's formats are saved in test/fixtures/wire/(version)/ (see the
// README there). A rename that changed what phones sent broke sharing
// between phones in 1.1.1; these tests stop that happening quietly again.

const _wireDir = 'test/fixtures/wire';

/// Saved releases, oldest first.
List<String> _versions() => Directory(_wireDir)
    .listSync()
    .whereType<Directory>()
    .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
    .toList()
  ..sort(_compareVersions);

/// Orders "1.9.0" before "1.10.0", which comparing text does not.
int _compareVersions(String a, String b) {
  final x = a.split('.').map(int.parse).toList();
  final y = b.split('.').map(int.parse).toList();
  for (var i = 0; i < x.length && i < y.length; i++) {
    if (x[i] != y[i]) return x[i].compareTo(y[i]);
  }
  return x.length.compareTo(y.length);
}

String _read(String version, String file) =>
    File('$_wireDir/$version/$file').readAsStringSync();

/// The text inside a gzip+base64 payload, or the payload itself.
String _unpacked(String payload) {
  try {
    return utf8.decode(gzip.decode(base64Decode(payload)));
  } catch (_) {
    return payload;
  }
}

String _currentVersion() => RegExp(r'^version:\s*([0-9.]+)', multiLine: true)
    .firstMatch(File('pubspec.yaml').readAsStringSync())!
    .group(1)!;

class _NoHaptics implements IHapticFeedback {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _Scans implements BarcodeScannerInterface {
  _Scans(this.text);
  final String text;
  @override
  Future<ScanResult> scan() async =>
      ScanResult(type: ResultType.Barcode, rawContent: text);
}

class _Phone implements PlatformCheckerInterface {
  const _Phone();
  @override
  bool get isAndroid => false;
  @override
  bool get isIOS => true;
}

/// Scans [qrText] on a phone that is [me], receiving, and returns what it
/// took as sent by [from], or null if it refused the code.
Future<String?> _scan(WidgetTester tester, String qrText,
    {required DeviceName me, required DeviceName from}) async {
  final devices =
      DeviceConnectionService.createDevices(me, DeviceType.browserDevice);
  late BuildContext context;
  await tester.pumpWidget(Builder(builder: (c) {
    context = c;
    return const SizedBox();
  }));
  final controller = QRConnectionController(
    devices: devices,
    platformChecker: const _Phone(),
    callback: () {},
    barcodeScanner: _Scans(qrText),
  );
  await controller.handleTap(context);
  if (controller.hasError) return null;
  return devices.getDevice(from)?.data;
}

void main() {
  final storage = AssistantStorageService.instance;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(
        Directory.systemTemp.createTempSync('wire_formats').path);
  });

  test('releases are saved to test against', () {
    expect(_versions(), contains('1.1.1'));
  });

  test('phones still announce the names every release knows', () {
    expect(getDeviceWireName(DeviceName.coach), 'Coach');
    expect(getDeviceWireName(DeviceName.raceTimer), 'Race Timer');
    expect(getDeviceWireName(DeviceName.bibRecorder), 'Bib Recorder');
    expect(getDeviceWireName(DeviceName.spectator), 'Spectator');
    // 1.1.1 phones announced the Timer as 'Timer'.
    expect(getDeviceNameFromString('Timer'), DeviceName.raceTimer);
  });

  for (final version in _versions()) {
    group('what $version sent', () {
      test('the Timer opens the race the coach sent', () async {
        final db = await storage.database;
        await db.delete('race_history');
        final timer =
            TimingController(storage: storage, hapticFeedback: _NoHaptics());
        await timer.initialLoad;
        // Wirelessly the Timer gets the race alone; by QR code, the Bib
        // Recorder's race and roster.
        for (final file in ['race_to_timer.txt', 'race_to_bib_recorder.txt']) {
          await timer.loadRaceFromCoach(_read(version, file));
          expect(timer.currentRace?.name, sampleRace.name, reason: file);
          expect(timer.currentRace?.date.millisecondsSinceEpoch,
              sampleRace.date.millisecondsSinceEpoch, reason: file);
        }
        timer.dispose();
      });

      test('the Bib Recorder reads the race and roster', () async {
        final parts = _read(version, 'race_to_bib_recorder.txt').split('---');
        expect(parts, hasLength(2));
        final race = RaceRecord.fromEncodedString(parts[0]);
        expect(race.name, sampleRace.name);
        final roster = await BibDecodeUtils.decodeEncodedRunners(parts[1]);
        final runners = (roster as Success).value as List;
        expect([for (final r in runners) (r.bib, r.name, r.teamAbbreviation, r.grade)],
            [for (final r in sampleRoster) (r.bib, r.name, r.teamAbbreviation, r.grade)]);
      });

      test('the coach reads the Timer\'s times, every one', () async {
        final times = await TimingDecodeUtils.decodeEncodedTimingData(
            _read(version, 'times_to_coach.txt'),
            strict: true);
        expect([for (final t in times) (t.time, t.conflict?.type, t.conflict?.offBy)],
            [for (final t in sampleTimes) (t.time, t.conflict?.type, t.conflict?.offBy)]);
      });

      test('the coach reads the Bib Recorder\'s bibs in order', () async {
        final bibs = await BibDecodeUtils.decodeEncodedRunners(
            _read(version, 'bibs_to_coach.txt'));
        final list = (bibs as Success).value as List;
        expect([for (final b in list) b.bib], ['102', '101', '007']);
      });

      test('spectators read the results', () {
        final decoded = RaceShareDecoder.decodeWithRaw(
            _read(version, 'results_to_spectators.txt'));
        final results = (decoded as Success).value.results;
        expect([for (final r in results.individualResults) (r.place, r.name, r.finishTime)],
            [for (final r in sampleResults) (r.place, r.runner!.name, r.finishTime)]);
      });

      test('the transfer packets are read', () {
        final packets = [
          for (final line in _read(version, 'packets.txt').split('\n'))
            Package.fromString(line),
        ];
        expect([for (final p in packets) (p.number, p.type, p.data)],
            [(1, 'DATA', 'first chunk'), (1, 'ACK', null), (2, 'FIN', null)]);
        expect(packets.first.checksumsMatch(), isTrue);
      });

      testWidgets('QR codes are scanned', (tester) async {
        final raceAndRoster = _read(version, 'race_to_bib_recorder.txt');
        final times = _read(version, 'times_to_coach.txt');
        final bibs = _read(version, 'bibs_to_coach.txt');

        expect(await _scan(tester, 'Coach:$raceAndRoster',
                me: DeviceName.raceTimer, from: DeviceName.coach),
            raceAndRoster);
        expect(await _scan(tester, 'Coach:$raceAndRoster',
                me: DeviceName.bibRecorder, from: DeviceName.coach),
            raceAndRoster);
        for (final timerName in ['Race Timer', 'Timer']) {
          expect(await _scan(tester, '$timerName:$times',
                  me: DeviceName.coach, from: DeviceName.raceTimer),
              times, reason: '$timerName QR code');
        }
        expect(await _scan(tester, 'Bib Recorder:$bibs',
                me: DeviceName.coach, from: DeviceName.bibRecorder),
            bibs);
      });
    });
  }

  // Changing a format is allowed, but never by accident: phones on the
  // last release must still read what this one sends, and this one must
  // read theirs. If a change is meant, keep reading the old format, bump
  // the version and save the new one (see test/fixtures/wire/README.md).
  test('this version sends what it saved', () async {
    final latest = _versions().last;
    final current = await currentWireFormats();
    for (final entry in current.entries) {
      final saved = _read(latest, entry.key);
      if (entry.key == 'race_to_bib_recorder.txt') {
        final a = entry.value.split('---'), b = saved.split('---');
        expect(a[0], b[0], reason: entry.key);
        expect(_unpacked(a[1]), _unpacked(b[1]), reason: entry.key);
      } else {
        expect(_unpacked(entry.value), _unpacked(saved),
            reason: '${entry.key} is not what $latest sent. If you meant '
                'to change it, see test/fixtures/wire/README.md.');
      }
    }
    expect(_compareVersions(_currentVersion(), latest) >= 0, isTrue);
  });
}
