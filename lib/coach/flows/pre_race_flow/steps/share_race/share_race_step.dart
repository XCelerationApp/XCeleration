import 'package:xceleration/coach/flows/model/flow_model.dart';
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
          nextLabel: 'Done Sending',
        );
}
