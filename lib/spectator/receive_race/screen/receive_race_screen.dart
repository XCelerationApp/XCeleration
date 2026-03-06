import 'package:flutter/material.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/services/nearby_connections.dart';
import 'package:xceleration/core/utils/connection_utils.dart';
import 'package:xceleration/core/utils/data_protocol.dart';
import 'package:xceleration/core/components/connection_components.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/connection/controller/wireless_connection_controller.dart';
import 'package:provider/provider.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/race_share_decoder.dart';
import 'package:xceleration/spectator/services/spectator_storage_service.dart';
import 'package:xceleration/shared/services/race_results_service.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import 'package:xceleration/coach/race_results/widgets/team_results_widget.dart';
import 'package:xceleration/coach/race_results/widgets/individual_results_widget.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'dart:convert';
import 'dart:io';

class ReceiveRaceScreen extends StatefulWidget {
  final bool fromSpectator;
  const ReceiveRaceScreen({super.key, required this.fromSpectator});

  @override
  State<ReceiveRaceScreen> createState() => _ReceiveRaceScreenState();
}

class _ReceiveRaceScreenState extends State<ReceiveRaceScreen> {
  late DevicesManager devices;

  @override
  void initState() {
    super.initState();
    devices = DeviceConnectionService.createDevices(
      DeviceName.spectator,
      DeviceType.browserDevice,
      toSpectator: widget.fromSpectator,
    );
  }

  Future<void> _onComplete() async {
    // On browser, data will be placed on the targeted ConnectedDevice
    final data = devices.coach?.data ?? devices.spectator?.data;
    if (data == null || data.isEmpty) {
      if (!mounted) return;
      DialogUtils.showErrorDialog(context, message: 'No data received');
      return;
    }

    final result = RaceShareDecoder.decodeWithRaw(data);

    switch (result) {
      case Failure(:final error):
        Logger.e('[ReceiveRaceScreen._onComplete] ${error.originalException}');
        if (!mounted) return;
        DialogUtils.showErrorDialog(context, message: error.userMessage);
        return;
      case Success(:final value):
        // Save to local storage first
        await _saveRaceToLocalStorage(value.rawEncoded, value.results);

        if (!mounted) return;

        // Close the receive sheet
        Navigator.of(context).pop();

        // Show results in a sheet
        await sheet(
          context: context,
          title: value.results.resultsTitle,
          body: ReceiveRacePreviewSheet(
            data: value.results,
            encodedPayload: value.rawEncoded,
          ),
        );
    }
  }

  Future<void> _saveRaceToLocalStorage(
      String encodedPayload, RaceResultsData resultsData) async {
    try {
      // Decode the payload to extract race metadata
      final decoded = utf8.decode(gzip.decode(base64Decode(encodedPayload)));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      final raceMap = map['race'] as Map<String, dynamic>;

      // Save the race to local storage
      await SpectatorStorageService.instance.saveRace(
        raceUuid: raceMap['uuid']?.toString(),
        raceName: raceMap['name']?.toString() ?? 'Race',
        raceDate: raceMap['race_date']?.toString(),
        location: raceMap['location']?.toString(),
        distance: (raceMap['distance'] as num?)?.toDouble(),
        distanceUnit: raceMap['distance_unit']?.toString(),
        encodedPayload: encodedPayload,
        raceData: resultsData.resultsTitle,
      );

      Logger.d('Race saved to local storage');
    } catch (e) {
      Logger.e('Failed to save race to local storage: $e');
      // Don't rethrow - we still want to show the results even if save fails
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show as a sheet-style page content
    return Material(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              widget.fromSpectator
                  ? 'Searching for nearby spectators...\nThis will automatically connect and receive a race.'
                  : 'Searching for nearby coaches...\nThis will automatically connect and receive a race.',
            ),
            const SizedBox(height: 16),
            ChangeNotifierProvider(
              create: (_) {
                final svc = DeviceConnectionService(
                  devices,
                  'wirelessconn',
                  getDeviceNameString(devices.currentDeviceName),
                  devices.currentDeviceType,
                  NearbyConnections(),
                );
                return WirelessConnectionController(
                  deviceConnectionService: svc,
                  protocol: Protocol(deviceConnectionService: svc),
                  devices: devices,
                  callback: _onComplete,
                );
              },
              child: const WirelessConnectionWidget(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet widget to preview received race results
class ReceiveRacePreviewSheet extends StatelessWidget {
  final RaceResultsData data;
  final String encodedPayload;

  const ReceiveRacePreviewSheet({
    super.key,
    required this.data,
    required this.encodedPayload,
  });

  Future<void> _shareRace(BuildContext context) async {
    try {
      final devices = DeviceConnectionService.createDevices(
        DeviceName.spectator,
        DeviceType.advertiserDevice,
        data: encodedPayload,
        toSpectator: true, // Share to another spectator
      );

      if (!context.mounted) return;

      await sheet(
        context: context,
        title: 'Share to Another Spectator',
        body: ChangeNotifierProvider(
          create: (_) {
            final svc = DeviceConnectionService(
              devices,
              'wirelessconn',
              getDeviceNameString(devices.currentDeviceName),
              devices.currentDeviceType,
              NearbyConnections(),
            );
            return WirelessConnectionController(
              deviceConnectionService: svc,
              protocol: Protocol(deviceConnectionService: svc),
              devices: devices,
              callback: () {
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          },
          child: const WirelessConnectionWidget(),
        ),
      );
    } catch (e) {
      Logger.e('Failed to share race: $e');
      if (context.mounted) {
        DialogUtils.showErrorDialog(context, message: 'Failed to share race');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Results content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TeamResultsWidget(raceResultsData: data),
                    IndividualResultsWidget(
                      raceResultsData: data,
                      initialVisibleCount: 10,
                    ),
                    const SizedBox(height: 80), // Extra padding for FAB
                  ],
                ),
              ),
            ),
          ],
        ),
        // Floating action button for sharing
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'share_received_race',
            onPressed: () => _shareRace(context),
            backgroundColor: AppColors.primaryColor,
            child: const Icon(Icons.share, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
