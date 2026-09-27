import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/core/connection/controller/wireless_connection_controller.dart';
import 'package:xceleration/core/utils/enums.dart';

import '../helpers/fake_nearby_network.dart';

// Phones passing races, times and bibs to each other, with the real
// connection code on every phone and a pretend radio between them. These
// are the cases that failed at the demo and in real use: a phone that
// opened its screen first, a second send, a dropped connection, Try again.

const coach = DeviceName.coach;
const timer = DeviceName.raceTimer;
const bibRecorder = DeviceName.bibRecorder;
const advertiser = DeviceType.advertiserDevice;
const browser = DeviceType.browserDevice;

final race = RaceRecord(
  raceId: 3,
  date: DateTime(2026, 9, 12),
  name: 'Invitational',
  type: 'race',
).encode();
final raceWithRoster = '$race---{"teams":["NHS"],"rows":[["101","Ava Lee",0,"11"]]}';

/// Long enough to need many packets, so a transfer can be cut partway.
final longTimes = List.generate(600, (i) => '${i + 1},15:${(i % 60).toString().padLeft(2, '0')}.${i % 100}').join(';');

void main() {
  late FakeNearbyNetwork net;

  setUp(() => net = FakeNearbyNetwork());

  SharingSession coachSends(FakePhone phone) => openSharing(phone, coach, advertiser,
      dataFor: {timer: race, bibRecorder: raceWithRoster});

  test('the coach sends the race to the Timer', () {
    fakeAsync((fake) {
      final c = coachSends(net.phone('coach'));
      final t = openSharing(net.phone('timer'), timer, browser);

      fake.elapse(const Duration(seconds: 30));

      expect(t.receivedFrom(coach), race);
      expect(t.completions, 1);
      expect(c.statusOf(timer), ConnectionStatus.finished);
      c.close();
      t.close();
    });
  });

  // Failed at the demo: after seven seconds the search restarted, the
  // screen took that as the end, and the phones never connected.
  test('the Timer opens first and waits a minute for the coach', () {
    fakeAsync((fake) {
      final t = openSharing(net.phone('timer'), timer, browser);
      fake.elapse(const Duration(minutes: 1));

      final c = coachSends(net.phone('coach'));
      fake.elapse(const Duration(seconds: 30));

      expect(t.receivedFrom(coach), race);
      expect(t.completions, 1);
      c.close();
      t.close();
    });
  });

  test('the coach opens first and waits five minutes for the Timer', () {
    fakeAsync((fake) {
      final c = coachSends(net.phone('coach'));
      fake.elapse(const Duration(minutes: 5));

      final t = openSharing(net.phone('timer'), timer, browser);
      fake.elapse(const Duration(seconds: 30));

      expect(t.receivedFrom(coach), race);
      c.close();
      t.close();
    });
  });

  test('the Timer and the Bib Recorder get the race at the same time', () {
    fakeAsync((fake) {
      final c = coachSends(net.phone('coach'));
      final t = openSharing(net.phone('timer'), timer, browser);
      final b = openSharing(net.phone('bib'), bibRecorder, browser);

      fake.elapse(const Duration(seconds: 45));

      expect(t.receivedFrom(coach), race);
      expect(b.receivedFrom(coach), raceWithRoster);
      expect(c.completions, 1, reason: 'the coach is done once both have it');
      c.close();
      t.close();
      b.close();
    });
  });

  // The plugin kept the last session's phones, so a second send saw the
  // Timer "connected" with nothing behind it.
  test('the race can be sent again on the same phones', () {
    fakeAsync((fake) {
      final coachPhone = net.phone('coach');
      final timerPhone = net.phone('timer');
      var c = coachSends(coachPhone);
      var t = openSharing(timerPhone, timer, browser);
      fake.elapse(const Duration(seconds: 30));
      expect(t.receivedFrom(coach), race);
      c.close();
      t.close();
      fake.elapse(const Duration(seconds: 5));

      c = coachSends(coachPhone);
      t = openSharing(timerPhone, timer, browser);
      fake.elapse(const Duration(seconds: 30));

      expect(t.receivedFrom(coach), race);
      expect(t.completions, 1);
      c.close();
      t.close();
    });
  });

  test('a connection dropped partway through is made again and finishes', () {
    fakeAsync((fake) {
      final coachPhone = net.phone('coach');
      final timerPhone = net.phone('timer');
      // The Timer sends its times to the coach, as at Load Results.
      final t = openSharing(timerPhone, timer, advertiser,
          dataFor: {coach: longTimes});
      final c = openSharing(coachPhone, coach, browser);

      // Cut the connection once some packets are through.
      for (var i = 0; i < 600 && net.delivered.length < 6; i++) {
        fake.elapse(const Duration(milliseconds: 50));
      }
      expect(net.delivered.length, greaterThanOrEqualTo(6));
      net.dropConnection(coachPhone, timerPhone);

      fake.elapse(const Duration(minutes: 2));

      expect(c.receivedFrom(timer), longTimes);
      expect(t.statusOf(coach), ConnectionStatus.finished);
      c.close();
      t.close();
    });
  });

  test('lost messages are sent again', () {
    fakeAsync((fake) {
      var lost = 0;
      net.loseMessage = (from, to, message) => lost++ < 3;
      final c = coachSends(net.phone('coach'));
      final t = openSharing(net.phone('timer'), timer, browser);

      fake.elapse(const Duration(minutes: 1));

      expect(lost, greaterThanOrEqualTo(3));
      expect(t.receivedFrom(coach), race);
      c.close();
      t.close();
    });
  });

  // Try again after a time-out used to fail every time: the time-out had
  // shut the service and protocol for good.
  test('Try again after a time-out finds the coach', () {
    fakeAsync((fake) {
      final t = openSharing(net.phone('timer'), timer, browser);
      fake.elapse(
          WirelessConnectionController.searchTimeout + const Duration(minutes: 1));
      expect(t.controller.wirelessConnectionError, WirelessConnectionError.timeout);

      final c = coachSends(net.phone('coach'));
      t.controller.retry();
      fake.elapse(const Duration(seconds: 30));

      expect(t.controller.wirelessConnectionError, isNull);
      expect(t.receivedFrom(coach), race);
      c.close();
      t.close();
    });
  });

  test('the Timer sends its times to the coach', () {
    fakeAsync((fake) {
      final t = openSharing(net.phone('timer'), timer, advertiser,
          dataFor: {coach: longTimes});
      final c = openSharing(net.phone('coach'), coach, browser);

      fake.elapse(const Duration(minutes: 1));

      expect(c.receivedFrom(timer), longTimes);
      expect(c.statusOf(timer), ConnectionStatus.finished);
      c.close();
      t.close();
    });
  });

  // A Timer on 1.1.1 calls itself 'Timer'; the coach ignored it.
  test('a Timer on 1.1.1 still gets the race', () {
    fakeAsync((fake) {
      final c = coachSends(net.phone('coach'));
      final t = openSharing(net.phone('timer'), timer, browser, wireName: 'Timer');

      fake.elapse(const Duration(seconds: 30));

      expect(t.receivedFrom(coach), race);
      c.close();
      t.close();
    });
  });

  test('a phone that leaves the app while searching connects on return', () {
    fakeAsync((fake) {
      final timerPhone = net.phone('timer');
      final t = openSharing(timerPhone, timer, browser);
      fake.elapse(const Duration(seconds: 5));
      timerPhone.goToBackground();
      fake.elapse(const Duration(seconds: 20));

      final c = coachSends(net.phone('coach'));
      fake.elapse(const Duration(seconds: 5));
      timerPhone.returnToForeground();
      fake.elapse(const Duration(seconds: 30));

      expect(t.receivedFrom(coach), race);
      c.close();
      t.close();
    });
  });
}
