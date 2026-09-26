import 'package:flutter/material.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';
import '../../../../../core/components/dialog_utils.dart';
import '../../../../../core/services/device_connection_service.dart';
import 'widgets/share_race_widget.dart';

/// A FlowStep implementation for the share runners step in the pre-race flow
class ShareRaceStep extends FlowStep {
  final DevicesManager devices;
  ShareRaceStep({required this.devices})
      : super(
          title: 'Send to Volunteers',
          description:
              'On each volunteer\'s phone, open XCeleration, choose Assistant, '
              'then Timer or Bib Recorder, and tap Get Race from Coach.',
          content: ShareRaceWidget(devices: devices),
          canProceed: () => true,
          nextLabel: 'Done',
          beforeNext: (context) => confirmUnsent(context, devices),
        );

  /// Asks before finishing while a volunteer's phone has not received the
  /// race: Done used to say "Race sent" either way. A race shown by QR code
  /// is never confirmed here, so the coach can still carry on.
  static Future<void> confirmUnsent(
      BuildContext context, DevicesManager devices) async {
    final waiting = [
      if (devices.raceTimer?.isFinished == false) 'the Timer',
      if (devices.bibRecorder?.isFinished == false) 'the Bib Recorder',
    ];
    if (waiting.isEmpty) return;
    final who = waiting.join(' and ');
    final carryOn = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Not Received Yet',
      content: '${who[0].toUpperCase()}${who.substring(1)} '
          '${waiting.length == 1 ? 'has' : 'have'} not received the race on '
          'this screen. If they scanned the QR code, you are done. If not, '
          'wait for them, or send it again later from the race.',
      confirmText: 'Done',
      cancelText: 'Keep Waiting',
    );
    if (!carryOn) throw const FlowStepBlocked();
  }
}
