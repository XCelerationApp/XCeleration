import 'package:flutter/material.dart';
import '../../../core/components/button_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../utils/sheet_utils.dart';
import '../../../core/components/device_connection_widget.dart';
import '../../../core/services/device_connection_service.dart';
import '../model/timing_data.dart';
import '../../../utils/enums.dart';

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
        if (startTime == null && hasRecords)
          _buildShareButton(context),
        _buildLogButton(context),
      ],
    );
  }

  Widget _buildRaceControlButton(BuildContext context) {
    final endTime = timingData.endTime;
    final hasStoppedRace = startTime == null && endTime != null && hasRecords;
    
    final buttonText = startTime != null ? 'Stop' : (hasStoppedRace ? 'Continue' : 'Start');
    final buttonColor = startTime == null ? Colors.green : Colors.red;
    
    return CircularButton(
      text: buttonText,
      color: buttonColor,
      fontSize: 18,
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
            return ElevatedButton(
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
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 78),
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                foregroundColor: AppColors.darkColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(39),
                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.share, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Share Times',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.darkColor,
                    ),
                    maxLines: 1,
                  ),
                ],
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
