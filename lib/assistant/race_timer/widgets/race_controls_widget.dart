import 'package:flutter/material.dart';
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
        if (startTime == null && hasRecords) _buildShareButton(context),
        _buildLogButton(context),
      ],
    );
  }

  Widget _buildRaceControlButton(BuildContext context) {
    final endTime = timingData.endTime;
    final hasStoppedRace = startTime == null && endTime != null && hasRecords;

    final buttonText =
        startTime != null ? 'Stop' : (hasStoppedRace ? 'Resume' : 'Start');
    final buttonColor = startTime == null ? Colors.green : Colors.red;

    return CircularButton(
      text: buttonText,
      color: buttonColor,
      fontSize: hasStoppedRace ? 16 : 18,
      fontWeight: FontWeight.w600,
      onPressed: startTime == null ? onStartRace : onStopRace,
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
    return CircularButton(
      text: (!hasRecords || startTime != null) ? 'Log' : 'Clear',
      color: (!hasRecords && startTime == null)
          ? const Color.fromARGB(255, 201, 201, 201)
          : const Color(0xFF777777),
      fontSize: 18,
      fontWeight: FontWeight.w600,
      onPressed: (hasRecords && startTime == null)
          ? onClearRaceTimes
          : (startTime != null ? onLogButtonPress : null),
    );
  }
}
