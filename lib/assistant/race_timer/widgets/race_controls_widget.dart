import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../core/components/device_connection_widget.dart';
import '../../../core/services/device_connection_service.dart';
import '../../../core/utils/enums.dart';
import '../../../core/components/button_components.dart';
import '../controller/timing_controller.dart';

class RaceControlsWidget extends StatelessWidget {
  final TimingController controller;

  const RaceControlsWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildRaceControlButton(context),
        if (controller.raceStopped == true && controller.hasTimingData)
          _buildShareButton(context),
        _buildLogButton(context),
      ],
    );
  }

  Widget _buildRaceControlButton(BuildContext context) {
    final buttonText = controller.raceStopped == false
        ? 'Stop'
        : (controller.startTime != null ? 'Resume' : 'Start');
    final buttonColor = controller.raceStopped ? Colors.green : Colors.red;

    return CircularButton(
      text: buttonText,
      color: buttonColor,
      fontSize: controller.raceStopped ? 16 : 18,
      fontWeight: FontWeight.w600,
      onPressed:
          controller.raceStopped ? controller.startRace : controller.stopRace,
    );
  }

  Widget _buildShareButton(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ActionButton(
              height: 70,
              text: 'Share Times',
              icon: Icons.share,
              iconSize: 18,
              fontSize: 18,
              textColor: AppColors.mediumColor,
              backgroundColor: AppColors.backgroundColor,
              borderColor: AppColors.mediumColor,
              fontWeight: FontWeight.w500,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              borderRadius: 30,
              isPrimary: false,
              onPressed: () async {
                final encodedData = await controller.encodedRecords();
                if (!context.mounted) return;

                sheet(
                  context: context,
                  title: 'Share Times',
                  body: deviceConnectionWidget(
                    context,
                    DeviceConnectionService.createDevices(
                      DeviceName.raceTimer,
                      DeviceType.advertiserDevice,
                      data: encodedData,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogButton(BuildContext context) {
    // Determine if button should be enabled
    final bool isEnabled = controller.raceStopped
        ? controller
            .hasTimingData // Clear button: enabled only if there are records
        : controller.startTime !=
            null; // Log button: enabled only if race has started

    // Determine button text
    final String buttonText = controller.raceStopped && controller.hasTimingData ? 'Clear' : 'Log';

    // Determine button color based on enabled state
    final Color buttonColor = isEnabled
        ? const Color(0xFF777777) // Enabled: dark gray
        : const Color.fromARGB(255, 201, 201, 201); // Disabled: light gray

    // Determine button function
    final VoidCallback? buttonFunction = isEnabled
        ? (controller.raceStopped
            ? controller.clearRaceTimes
            : controller.handleLogButtonPress)
        : null;

    return CircularButton(
      text: buttonText,
      color: buttonColor,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      onPressed: buttonFunction,
    );
  }
}
