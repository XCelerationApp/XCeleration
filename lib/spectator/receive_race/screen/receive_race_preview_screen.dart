import 'package:flutter/material.dart';
import 'package:xceleration/shared/services/race_results_service.dart';
import 'package:xceleration/coach/race_results/widgets/team_results_widget.dart';
import 'package:xceleration/coach/race_results/widgets/individual_results_widget.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/components/device_connection_widget.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import 'package:xceleration/spectator/services/spectator_storage_service.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class ReceiveRacePreviewScreen extends StatefulWidget {
  final RaceResultsData data;
  final String? encodedPayload;
  const ReceiveRacePreviewScreen(
      {super.key, required this.data, this.encodedPayload});

  @override
  State<ReceiveRacePreviewScreen> createState() =>
      _ReceiveRacePreviewScreenState();
}

class _ReceiveRacePreviewScreenState extends State<ReceiveRacePreviewScreen> {
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Automatically save the race when the screen is loaded
    _saveRace();
  }

  Future<void> _saveRace() async {
    if (_isSaving || widget.encodedPayload == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Decode the payload to extract race metadata
      final Uint8List b = base64Decode(widget.encodedPayload!);
      final String decoded = utf8.decode(gzip.decode(b));
      final Map<String, dynamic> map =
          jsonDecode(decoded) as Map<String, dynamic>;
      final raceMap = map['race'] as Map<String, dynamic>;

      // Save the race to local storage
      await SpectatorStorageService.instance.saveRace(
        raceUuid: raceMap['uuid']?.toString(),
        raceName: raceMap['name']?.toString() ?? 'Race',
        raceDate: raceMap['race_date']?.toString(),
        location: raceMap['location']?.toString(),
        distance: (raceMap['distance'] as num?)?.toDouble(),
        distanceUnit: raceMap['distance_unit']?.toString(),
        encodedPayload: widget.encodedPayload!,
        raceData: widget.data.resultsTitle, // Store just the title for now
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    } catch (e) {
      Logger.e('Failed to save race: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        DialogUtils.showErrorDialog(context,
            message: 'Failed to save race locally');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.data.resultsTitle),
        actions: [
          if (widget.encodedPayload != null &&
              widget.encodedPayload!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share to another spectator',
              onPressed: () async {
                final devices = DeviceConnectionService.createDevices(
                  DeviceName.spectator,
                  DeviceType.advertiserDevice,
                  data: widget.encodedPayload,
                  toSpectator: true,
                );
                await sheet(
                  context: context,
                  title: 'Share Wirelessly',
                  body: DeviceConnectionWidget(devices: devices),
                );
              },
            ),
        ],
      ),
      backgroundColor: AppColors.backgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TeamResultsWidget(raceResultsData: widget.data),
            IndividualResultsWidget(
                raceResultsData: widget.data, initialVisibleCount: 10),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
