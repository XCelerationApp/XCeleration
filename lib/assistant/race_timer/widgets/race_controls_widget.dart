import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xcelerate/core/theme/app_colors.dart';
import '../../../utils/sheet_utils.dart';
import '../../../core/components/device_connection_widget.dart';
import '../../../core/services/device_connection_service.dart';
import '../model/timing_data.dart';
import '../../../utils/enums.dart';
import '../../../core/components/button_components.dart';

class RaceControlsWidget extends StatelessWidget {
  final DateTime? startTime;
  final TimingData timingData;
  final VoidCallback onStartRace;
  final VoidCallback onStopRace;
  final VoidCallback onClearRaceTimes;
  final Function() onLogButtonPress;
  final bool hasRecords;
  final bool isAudioPlayerReady;

  const RaceControlsWidget({
    super.key,
    required this.startTime,
    required this.timingData,
    required this.onStartRace,
    required this.onStopRace,
    required this.onClearRaceTimes,
    required this.onLogButtonPress,
    required this.hasRecords,
    required this.isAudioPlayerReady,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildRaceControlButton(context),
        if (timingData.raceStopped == true && hasRecords) _buildShareButton(context),
        _buildLogButton(context),
      ],
    );
  }

  Widget _buildRaceControlButton(BuildContext context) {
    final buttonText =
        timingData.raceStopped == false ? 'Stop' : (startTime != null ? 'Resume' : 'Start');
    final buttonColor = timingData.raceStopped ? Colors.green : Colors.red;

    return CircularButton(
      text: buttonText,
      color: buttonColor,
      fontSize: timingData.raceStopped ? 16 : 18,
      fontWeight: FontWeight.w600,
      onPressed: timingData.raceStopped ? onStartRace : onStopRace,
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
              onPressed: () => sheet(
                context: context,
                title: 'Share Times',
                body: deviceConnectionWidget(
                  context,
                  DeviceConnectionService.createDevices(
                    DeviceName.raceTimer,
                    DeviceType.advertiserDevice,
                    data: timingData.encode(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogButton(BuildContext context) {
    return Consumer<TimingData>(
      builder: (context, timingData, child) {
        return CircularButton(
          text: (!hasRecords || timingData.raceStopped == false) ? 'Log' : 'Clear',
          color: (!hasRecords && timingData.raceStopped)
              ? const Color.fromARGB(255, 201, 201, 201)
              : const Color(0xFF777777),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          onPressed: (hasRecords && timingData.raceStopped)
              ? onClearRaceTimes
              : (timingData.raceStopped ? null : onLogButtonPress),
        );
      },
    );
  }
}
