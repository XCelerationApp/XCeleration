import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import '../../controller/flow_controller.dart';
import '../../model/flow_model.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/enums.dart';
import '../../../../core/services/device_connection_service.dart';
import '../../../../core/utils/encode_utils.dart';
import '../steps/review_runners/review_runners_step.dart';
import '../steps/share_race/share_race_step.dart';
import '../steps/flow_complete/pre_race_flow_complete_step.dart';
import '../../../../core/components/device_connection_widget.dart';
import '../../../../core/components/dialog_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/sheet_utils.dart';

/// Function type that matches the [showFlow] top-level function signature,
/// used to allow injection in tests.
typedef ShowFlowFn = Future<bool> Function({
  required BuildContext context,
  required List<FlowStep> steps,
  bool showProgressIndicator,
  int initialIndex,
  StepChangedCallback? onStepChanged,
  void Function(int lastIndex)? onDismiss,
});

class PreRaceController {
  final MasterRace masterRace;
  final DevicesManager devices;
  final Future<String> Function(MasterRace) encodeRaceData;
  final Future<String> Function(MasterRace) encodeBibData;
  final ShowFlowFn _showFlow;

  late ReviewRunnersStep _reviewRunnersStep;
  late ShareRaceStep _shareRaceStep;
  late PreRaceFlowCompleteStep _preRaceFlowCompleteStep;
  int? _lastStepIndex;

  PreRaceController({
    required this.masterRace,
    DevicesManager? devices,
    Future<String> Function(MasterRace)? encodeRaceData,
    Future<String> Function(MasterRace)? encodeBibData,
    ShowFlowFn? showFlowFn,
  })  : devices = devices ??
            DeviceConnectionService.createDevices(
              DeviceName.coach,
              DeviceType.advertiserDevice,
              data: '',
            ),
        encodeRaceData =
            encodeRaceData ?? RaceEncodeUtils.getEncodedRaceData,
        encodeBibData =
            encodeBibData ?? BibEncodeUtils.getEncodedRunnersBibData,
        _showFlow = showFlowFn ?? showFlow {
    _initializeSteps();
  }

  void _initializeSteps() {
    _reviewRunnersStep = ReviewRunnersStep(
      masterRace: masterRace,
      onNext: _prepareShareData,
    );
    _shareRaceStep = ShareRaceStep(devices: devices);
    _preRaceFlowCompleteStep = PreRaceFlowCompleteStep();
  }

  /// Encodes the race and its roster for the assistants to receive.
  Future<void> _prepareShareData() async {
    final encodedRaceData = await encodeRaceData(masterRace);
    if (encodedRaceData == '') {
      Logger.e('Failed to encode race data');
      return;
    }
    devices.raceTimer!.data = encodedRaceData;
    final encodedBibData = await encodeBibData(masterRace);
    if (encodedBibData == '') {
      Logger.e('Failed to encode runners data');
      return;
    }
    devices.bibRecorder!.data = '$encodedRaceData---$encodedBibData';
  }

  Future<bool> showPreRaceFlow(
      BuildContext context, bool showProgressIndicator) async {
    final int startIndex = _lastStepIndex ?? 0;
    // Reopening past the review step skips the step that encodes the race,
    // and the roster may have changed since the sheet was closed.
    if (startIndex > 0) await _prepareShareData();
    // Ensure initial proceed state is computed before rendering the sheet
    await _reviewRunnersStep.seedInitialProceed();
    if (!context.mounted) {
      return false;
    }
    return await _showFlow(
      context: context,
      showProgressIndicator: showProgressIndicator,
      steps: _getSteps(),
      initialIndex: startIndex,
      onDismiss: (lastIndex) {
        _lastStepIndex = lastIndex;
      },
    );
  }

  /// Sends the race again after the send flow is done, for a volunteer who
  /// missed it, lost it, or needs the roster as changed since. Builds fresh
  /// connections, since the flow's own may have finished.
  Future<void> showSendAgainSheet(BuildContext context) async {
    final again = createDevices();
    final encodedRaceData = await encodeRaceData(masterRace);
    final encodedBibData = await encodeBibData(masterRace);
    if (encodedRaceData == '' || encodedBibData == '') {
      Logger.e('Failed to encode the race to send again');
      if (context.mounted) {
        DialogUtils.showErrorDialog(context,
            message: 'Could not prepare the race to send. Try again.');
      }
      return;
    }
    again.raceTimer!.data = encodedRaceData;
    again.bibRecorder!.data = '$encodedRaceData---$encodedBibData';
    if (!context.mounted) return;

    await sheet(
      context: context,
      title: 'Send Race Again',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'On the volunteer\'s phone, tap Get Race from Coach. Times and '
            'bibs already recorded for this race stay on their phone.',
            style: AppTypography.bodyRegular
                .copyWith(color: AppColors.mediumColor),
          ),
          const SizedBox(height: AppSpacing.lg),
          DeviceConnectionWidget(devices: again),
        ],
      ),
    );
  }

  /// Makes the coach's connections for sending the race; replaced in tests.
  @visibleForTesting
  DevicesManager Function() createDevices = () =>
      DeviceConnectionService.createDevices(
        DeviceName.coach,
        DeviceType.advertiserDevice,
        data: '',
      );

  List<FlowStep> _getSteps() {
    return [
      _reviewRunnersStep,
      _shareRaceStep,
      _preRaceFlowCompleteStep,
    ];
  }

  @visibleForTesting
  List<FlowStep> buildSteps() => _getSteps();
}
