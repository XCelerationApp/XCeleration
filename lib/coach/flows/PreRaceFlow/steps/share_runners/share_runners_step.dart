import 'package:xcelerate/coach/flows/model/flow_model.dart';
import '../../../../../core/services/device_connection_service.dart';
import 'widgets/share_results_widget.dart';

/// A FlowStep implementation for the share runners step in the pre-race flow
class ShareRunnersStep extends FlowStep {
  final DevicesManager devices;
  ShareRunnersStep({required this.devices})
      : super(
          title: 'Share Runners',
          description:
              'Share the runners with the bib recorders phone before starting the race.',
          content: ShareResultsWidget(devices: devices),
          canProceed: () => true,
        );
}
