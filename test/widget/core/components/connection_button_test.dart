import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/components/wireless_connection_button.dart';
import 'package:xceleration/core/components/qr_connection_components.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/enums.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ConnectionButtonContainer', () {
    testWidgets('renders its child widget', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ConnectionButtonContainer(
            child: Text('hello', key: Key('inner')),
          ),
        ),
      );

      expect(find.byKey(const Key('inner')), findsOneWidget);
    });

    testWidgets('occupies full available width', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ConnectionButtonContainer(
            child: SizedBox.shrink(),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      expect(container.constraints?.maxWidth, double.infinity);
    });
  });

  group('WirelessConnectionButton', () {
    ConnectedDevice makeDevice(ConnectionStatus status) {
      final device = ConnectedDevice(DeviceName.coach);
      device.status = status;
      return device;
    }

    testWidgets('shows loading skeleton when isLoading is true',
        (tester) async {
      final device = makeDevice(ConnectionStatus.searching);

      await tester.pumpWidget(
        _wrap(WirelessConnectionButton(device: device, isLoading: true)),
      );

      // Loading state renders grey placeholder containers, no status text
      expect(find.text('Searching'), findsNothing);
    });

    testWidgets('shows "Searching" status text in default state',
        (tester) async {
      final device = makeDevice(ConnectionStatus.searching);

      await tester.pumpWidget(
        _wrap(WirelessConnectionButton(device: device)),
      );

      expect(find.text('Searching'), findsOneWidget);
    });

    testWidgets('shows "Connected" status text when connected', (tester) async {
      final device = makeDevice(ConnectionStatus.connected);

      await tester.pumpWidget(
        _wrap(WirelessConnectionButton(device: device)),
      );

      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('shows "Done" when status is finished', (tester) async {
      final device = makeDevice(ConnectionStatus.finished);

      await tester.pumpWidget(
        _wrap(WirelessConnectionButton(device: device)),
      );

      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('shows error UI when status is error', (tester) async {
      final device = makeDevice(ConnectionStatus.error);

      await tester.pumpWidget(
        _wrap(WirelessConnectionButton(
          device: device,
          errorMessage: 'Connection timed out.',
        )),
      );

      expect(find.text('Connection unavailable'), findsOneWidget);
      expect(find.text('Connection timed out.'), findsOneWidget);
    });

    testWidgets('shows Retry button in error state when onRetry is provided',
        (tester) async {
      final device = makeDevice(ConnectionStatus.error);
      var retried = false;

      await tester.pumpWidget(
        _wrap(WirelessConnectionButton(
          device: device,
          onRetry: () => retried = true,
        )),
      );

      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('hides Retry button in error state when onRetry is null',
        (tester) async {
      final device = makeDevice(ConnectionStatus.error);

      await tester.pumpWidget(
        _wrap(WirelessConnectionButton(device: device)),
      );

      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('rebuilds when device status changes', (tester) async {
      final device = makeDevice(ConnectionStatus.searching);

      await tester.pumpWidget(
        _wrap(WirelessConnectionButton(device: device)),
      );
      expect(find.text('Searching'), findsOneWidget);

      device.status = ConnectionStatus.connected;
      await tester.pump();

      expect(find.text('Connected'), findsOneWidget);
    });
  });

  group('QRConnectionButton', () {
    testWidgets('shows "Show QR Code" for advertiser device type',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const QRConnectionButton(
          deviceName: DeviceName.coach,
          deviceType: DeviceType.advertiserDevice,
          connectionStatus: ConnectionStatus.searching,
        )),
      );

      expect(find.text('Show QR Code'), findsOneWidget);
    });

    testWidgets('shows "Scan QR Code" for browser device type',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const QRConnectionButton(
          deviceName: DeviceName.raceTimer,
          deviceType: DeviceType.browserDevice,
          connectionStatus: ConnectionStatus.searching,
        )),
      );

      expect(find.text('Scan QR Code'), findsOneWidget);
    });

    testWidgets('renders QR code icon', (tester) async {
      await tester.pumpWidget(
        _wrap(const QRConnectionButton(
          deviceName: DeviceName.coach,
          deviceType: DeviceType.advertiserDevice,
          connectionStatus: ConnectionStatus.searching,
        )),
      );

      expect(find.byIcon(Icons.qr_code), findsOneWidget);
    });
  });
}
