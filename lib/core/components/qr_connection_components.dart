import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../utils/enums.dart';
import '../utils/platform_checker.dart';
import '../connection/controller/qr_connection_controller.dart';
import '../services/device_connection_service.dart';
import 'dialog_utils.dart';
import 'wireless_connection_components.dart' show ConnectionButtonContainer;

class QRConnectionButton extends StatefulWidget {
  final DeviceName deviceName;
  final DeviceType deviceType;
  final ConnectionStatus connectionStatus;
  final Function()? onRetry;
  final String? errorMessage;
  final bool isLoading;
  final bool isDisabled;

  const QRConnectionButton({
    super.key,
    required this.deviceName,
    required this.deviceType,
    required this.connectionStatus,
    this.onRetry,
    this.errorMessage,
    this.isLoading = false,
    this.isDisabled = false,
  });

  @override
  State<QRConnectionButton> createState() => _QRConnectionButtonState();
}

class _QRConnectionButtonState extends State<QRConnectionButton> {
  @override
  Widget build(BuildContext context) {
    final iconColor =
        widget.isDisabled ? Colors.black26 : Colors.black54;
    final textColor =
        widget.isDisabled ? Colors.black26 : Colors.black87;
    return ConnectionButtonContainer(
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
                    color: iconColor,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Text(
                    widget.deviceType == DeviceType.advertiserDevice
                        ? 'Show QR Code'
                        : 'Scan QR Code',
                    style: TextStyle(
                      fontSize: 17,
                      color: textColor,
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
  final bool inSheet;

  const QRConnectionWidget({
    super.key,
    required this.devices,
    required this.callback,
    this.platformChecker = const PlatformChecker(),
    this.inSheet = false,
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
      inSheet: widget.inSheet,
    );
    _controller.addListener(_onControllerChange);
    for (final device in widget.devices.devices) {
      device.addListener(_onDeviceChange);
    }
  }

  void _onControllerChange() {
    if (_controller.hasError && mounted) {
      DialogUtils.showErrorDialog(
        context,
        message: _controller.error!.userMessage,
      );
    }
  }

  void _onDeviceChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    for (final device in widget.devices.devices) {
      device.removeListener(_onDeviceChange);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.devices.allDevicesFinished();
    return GestureDetector(
      onTap: isDisabled ? null : () => _controller.handleTap(context),
      child: QRConnectionButton(
        deviceName: widget.devices.currentDeviceName,
        deviceType: widget.devices.currentDeviceType,
        connectionStatus: ConnectionStatus.searching,
        isDisabled: isDisabled,
      ),
    );
  }
}
