import 'package:flutter/material.dart';
import 'package:xceleration/shared/services/race_results_service.dart';
import 'package:xceleration/coach/race_results/widgets/team_results_widget.dart';
import 'package:xceleration/coach/race_results/widgets/individual_results_widget.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/components/device_connection_widget.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';

class ReceiveRacePreviewScreen extends StatelessWidget {
  final RaceResultsData data;
  final String? encodedPayload;
  const ReceiveRacePreviewScreen(
      {super.key, required this.data, this.encodedPayload});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(data.resultsTitle),
        actions: [
          if (encodedPayload != null && encodedPayload!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share',
              onPressed: () async {
                final devices = DeviceConnectionService.createDevices(
                  DeviceName.spectator,
                  DeviceType.advertiserDevice,
                  data: encodedPayload,
                  toSpectator: true,
                );
                await sheet(
                  context: context,
                  title: 'Share Wirelessly',
                  body: deviceConnectionWidget(context, devices),
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
            TeamResultsWidget(raceResultsData: data),
            IndividualResultsWidget(
                raceResultsData: data, initialVisibleCount: 10),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
