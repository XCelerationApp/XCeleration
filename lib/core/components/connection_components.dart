import 'package:flutter/material.dart';
import '../utils/connection_utils.dart';
import '../services/device_connection_service.dart';
import 'dialog_utils.dart';
import '../utils/enums.dart';
import '../utils/platform_checker.dart';
import '../connection/controller/qr_connection_controller.dart';
import '../connection/controller/wireless_connection_controller.dart';
import 'package:provider/provider.dart';

class WirelessConnectionButton extends StatefulWidget {
  final ConnectedDevice device;
  final IconData? icon;
  final Function()? onRetry;
  final String? errorMessage;
  final bool isLoading;

  const WirelessConnectionButton({
    super.key,
    required this.device,
    this.icon = Icons.person,
    this.onRetry,
    this.errorMessage,
    this.isLoading = false,
  });

  WirelessConnectionButton get skeleton => WirelessConnectionButton(
        device: device,
        icon: icon,
        isLoading: true,
      );

  WirelessConnectionButton error(
      {WirelessConnectionError error = WirelessConnectionError.unknown,
      Function()? retryAction}) {
    late String message;
    if (error == WirelessConnectionError.unavailable) {
      message = 'Wireless connection is not available on this device.';
    } else if (error == WirelessConnectionError.timeout) {
      message = 'Connection timed out.';
    } else {
      message = 'An unknown error occurred.';
    }
    device.status = ConnectionStatus.error;
    return WirelessConnectionButton(
      device: device,
      icon: Icons.error_outline,
      errorMessage: message,
      onRetry: retryAction,
    );
  }

  @override
  State<WirelessConnectionButton> createState() =>
      _WirelessConnectionButtonState();
}

class _WirelessConnectionButtonState extends State<WirelessConnectionButton> {
  @override
  void initState() {
    super.initState();
    widget.device.addListener(_deviceStatusChanged);
  }

  void _deviceStatusChanged() {
    if (mounted) {
      setState(() {
        // Just trigger a rebuild
      });
    }
  }

  @override
  void dispose() {
    widget.device.removeListener(_deviceStatusChanged);
    super.dispose();
  }

  Widget _buildStatusIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.grey[400]!,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _getStatusText(),
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _getStatusText() {
    switch (widget.device.status) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.sending:
        return 'Sending';
      case ConnectionStatus.receiving:
        return 'Receiving';
      case ConnectionStatus.found:
        return 'Found';
      case ConnectionStatus.connecting:
        return 'Connecting';
      case ConnectionStatus.searching:
      default:
        return 'Searching';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 120,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Spacer(),
            Container(
              width: 80,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.device.status == ConnectionStatus.error) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[400],
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Connection unavailable',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.errorMessage ?? 'An unknown error occurred',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onRetry != null)
              TextButton(
                onPressed: widget.onRetry,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: const Text('Retry'),
              ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.icon ?? Icons.person,
            color: Colors.black54,
            size: 24,
          ),
          const SizedBox(width: 16),
          Text(
            getDeviceNameString(widget.device.name),
            style: const TextStyle(
              fontSize: 17,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.device.status == ConnectionStatus.finished) ...[
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
              ] else ...[
                _buildStatusIndicator()
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class QRConnectionButton extends StatefulWidget {
  final DeviceName deviceName;
  final DeviceType deviceType;
  final ConnectionStatus connectionStatus;
  final Function()? onRetry;
  final String? errorMessage;
  final bool isLoading;

  const QRConnectionButton({
    super.key,
    required this.deviceName,
    required this.deviceType,
    required this.connectionStatus,
    this.onRetry,
    this.errorMessage,
    this.isLoading = false,
  });

  @override
  State<QRConnectionButton> createState() => _QRConnectionButtonState();
}

class _QRConnectionButtonState extends State<QRConnectionButton> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code,
                    color: Colors.black54,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    widget.deviceType == DeviceType.advertiserDevice
                        ? 'Show QR Code'
                        : 'Scan QR Code',
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.black87,
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class QRConnectionWidget extends StatefulWidget {
  final DevicesManager devices;
  final Function callback;
  final PlatformCheckerInterface platformChecker;

  const QRConnectionWidget({
    super.key,
    required this.devices,
    required this.callback,
    this.platformChecker = const PlatformChecker(),
  });

  @override
  State<QRConnectionWidget> createState() => _QRConnectionState();
}

class _QRConnectionState extends State<QRConnectionWidget> {
  late QRConnectionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = QRConnectionController(
      devices: widget.devices,
      platformChecker: widget.platformChecker,
      callback: widget.callback,
    );
    _controller.addListener(_onControllerChange);
  }

  void _onControllerChange() {
    if (_controller.hasError && mounted) {
      DialogUtils.showErrorDialog(
        context,
        message: _controller.error!.userMessage,
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _controller.handleTap(context),
      child: QRConnectionButton(
        deviceName: widget.devices.currentDeviceName,
        deviceType: widget.devices.currentDeviceType,
        connectionStatus: ConnectionStatus.searching,
      ),
    );
  }
}

class WirelessConnectionWidget extends StatefulWidget {
  const WirelessConnectionWidget({super.key});

  @override
  State<WirelessConnectionWidget> createState() => _WirelessConnectionState();
}

class _WirelessConnectionState extends State<WirelessConnectionWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<WirelessConnectionController>().initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WirelessConnectionController>();

    if (controller.wirelessConnectionError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: WirelessConnectionButton(
              device: ConnectedDevice(DeviceName.coach),
            ).error(
              error: controller.wirelessConnectionError!,
              retryAction: controller.retry,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var device in controller.devices.otherDevices)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: controller.isLoading
                ? WirelessConnectionButton(device: device).skeleton
                : WirelessConnectionButton(device: device),
          ),
      ],
    );
  }
}
