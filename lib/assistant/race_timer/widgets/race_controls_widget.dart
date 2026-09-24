import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../core/components/device_connection_widget.dart';
import '../../../core/services/device_connection_service.dart';
import '../../../core/utils/enums.dart';
import '../../../core/components/button_components.dart';
import '../controller/timing_controller.dart';
import '../../shared/services/demo_race_generator.dart';
import '../../../core/components/dialog_utils.dart';

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
    final buttonColor = controller.currentRace == null
        ? const Color.fromARGB(255, 201, 201, 201)
        : controller.raceStopped
            ? Colors.green
            : Colors.red;

    return CircularButton(
      text: buttonText,
      color: buttonColor,
      fontSize: controller.raceStopped ? 16 : 18,
      fontWeight: FontWeight.w600,
      onPressed: controller.currentRace == null
          ? null
          : (controller.raceStopped
              ? controller.startRace
              : () => _handleStopRace(context)),
    );
  }

  Future<void> _handleStopRace(BuildContext context) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Stop the Race',
      content: 'Are you sure you want to stop the race?',
    );
    if (confirmed && context.mounted) {
      controller.stopRace();
    }
  }

  Widget _buildShareButton(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ActionButton(
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
            // Prevent sharing demo race
            if (controller.currentRace != null &&
                DemoRaceGenerator.isDemoRace(controller.currentRace!)) {
              DialogUtils.showMessageDialog(
                context,
                title: 'Demo Race',
                message:
                    'The demo race is for practice only and cannot be shared. Please load a real race from your coach to share results.',
              );
              return;
            }

            final encodedData = await controller.encodedRecords();
            if (!context.mounted) return;

            sheet(
              context: context,
              title: 'Share Times',
              body: DeviceConnectionWidget(
                devices: DeviceConnectionService.createDevices(
                  DeviceName.raceTimer,
                  DeviceType.advertiserDevice,
                  data: encodedData,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogButton(BuildContext context) {
    // Logs only while the race runs. Clearing the times is in the race menu,
    // away from Share Times, which it used to sit beside.
    final bool isEnabled =
        !controller.raceStopped && controller.startTime != null;

    return CircularButton(
      text: 'Log',
      color: isEnabled
          ? const Color(0xFF777777) // Enabled: dark gray
          : const Color.fromARGB(255, 201, 201, 201), // Disabled: light gray
      fontSize: 18,
      fontWeight: FontWeight.w600,
      onPressed: isEnabled ? () => _handleLogButtonPress(context) : null,
    );
  }

  Future<void> _handleLogButtonPress(BuildContext context) async {
    final error = await controller.handleLogButtonPress();
    if (error != null && context.mounted) {
      DialogUtils.showErrorDialog(context, message: error.userMessage);
    }
  }
}
