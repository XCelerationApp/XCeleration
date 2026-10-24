import 'package:flutter/material.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/race_from_coach.dart';
import 'package:xceleration/assistant/shared/services/assistant_storage_service.dart';
import 'package:xceleration/assistant/shared/services/received_race_resolver.dart';
import 'package:xceleration/assistant/shared/widgets/race_already_here_dialog.dart';
import 'package:xceleration/core/components/device_connection_widget.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/utils/connection_utils.dart';
import 'package:xceleration/core/utils/enums.dart';

class ShareRaceWidget extends StatelessWidget {
  final DevicesManager devices;
  const ShareRaceWidget({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
              child: DeviceConnectionWidget(devices: devices, inSheet: false)),
          if (devices.bibRecorder != null) ...[
            const SizedBox(height: AppSpacing.md),
            RecordBibsOnThisPhone(devices: devices),
          ],
        ],
      ),
    );
  }
}

/// Hands the race to this phone's own Bib Recorder, for a coach who records
/// bibs themselves: the phone cannot scan its own QR code or send to itself.
class RecordBibsOnThisPhone extends StatefulWidget {
  const RecordBibsOnThisPhone({super.key, required this.devices});

  final DevicesManager devices;

  @override
  State<RecordBibsOnThisPhone> createState() => _RecordBibsOnThisPhoneState();
}

class _RecordBibsOnThisPhoneState extends State<RecordBibsOnThisPhone> {
  bool _busy = false;

  Future<void> _handOver() async {
    final bibRecorder = widget.devices.bibRecorder!;
    final data = bibRecorder.data;
    if (data == null || data.isEmpty) {
      DialogUtils.showErrorDialog(context,
          message: 'The race is not ready to send yet. Try again.');
      return;
    }
    setState(() => _busy = true);
    final result = await storeRaceFromCoach(
      AssistantStorageService.instance,
      data,
      ask: (here) async => mounted
          ? askAboutRace(context, here, what: 'bibs')
          : ReceivedRaceChoice.update,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Failure(:final error):
        DialogUtils.showErrorDialog(context, message: error.userMessage);
      case Success(:final value):
        RaceHandedOver.bibRecorderRaceId = value.race.raceId;
        // This phone is the Bib Recorder: nothing more to send one.
        bibRecorder.status = ConnectionStatus.finished;
        await DialogUtils.showMessageDialog(
          context,
          title: 'Ready on This Phone',
          message: 'The race is on this phone\'s Bib Recorder. When the '
              'race starts, switch to Assistant and choose '
              '${getDeviceNameString(DeviceName.bibRecorder)}: the race '
              'opens there.\n\nAfter the race, on Load Results, tap Use '
              'Bibs From This Phone.',
          doneText: 'Got it',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const ValueKey('record_bibs_on_this_phone'),
      onPressed: _busy ? null : _handOver,
      icon: const Icon(Icons.smartphone, size: 18),
      label: const Text('Record bibs on this phone too'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.mediumColor,
        textStyle: AppTypography.smallBodySemibold,
      ),
    );
  }
}
