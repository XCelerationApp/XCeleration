import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../core/components/device_connection_widget.dart';
import '../../../core/services/device_connection_service.dart';
import '../../../core/utils/enums.dart';
import '../controller/timing_controller.dart';
import '../../shared/services/demo_race_generator.dart';
import '../../shared/widgets/race_day_controls.dart';
import '../../../core/components/dialog_utils.dart';
import 'bottom_controls_widget.dart';

/// The bottom of the Timer, where the thumb rests. It holds the one button
/// that matters at each moment: Start before the gun, Log Finish during the
/// race, and Share Times after it.
class RaceControlsWidget extends StatelessWidget {
  final TimingController controller;

  const RaceControlsWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (controller.currentRace == null) return const SizedBox.shrink();

    final started = controller.startTime != null;
    final running = started && !controller.raceStopped;

    if (running) {
      final next = (controller.runnerCount ?? 0) + 1;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.hasTimingData) ...[
            BottomControlsWidget(controller: controller),
            const SizedBox(height: AppSpacing.sm),
          ],
          BigActionButton(
            key: const ValueKey('timer_log_button'),
            label: 'Log Finish',
            sublabel: 'Runner $next',
            icon: Icons.timer_outlined,
            color: AppColors.primaryColor,
            height: 112,
            // Takes the time as the finger lands, not when it lifts.
            onTapDown: () => _handleLogButtonPress(context),
          ),
        ],
      );
    }

    if (!started) {
      return BigActionButton(
        key: const ValueKey('timer_start_button'),
        label: 'Start Race',
        sublabel: 'Tap when the gun goes',
        icon: Icons.play_arrow_rounded,
        color: Colors.green.shade600,
        height: 112,
        onTapDown: controller.startRace,
      );
    }

    // Stopped after starting.
    return Row(
      children: [
        Expanded(
          child: RaceDayButton(
            label: 'Resume',
            icon: Icons.play_arrow_rounded,
            color: Colors.green.shade700,
            height: 64,
            onPressed: controller.startRace,
          ),
        ),
        if (controller.hasTimingData) ...[
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: RaceDayButton(
              label: 'Share Times',
              icon: Icons.ios_share,
              color: AppColors.primaryColor,
              filled: true,
              height: 64,
              onPressed: () => _shareTimes(context),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _shareTimes(BuildContext context) async {
    // Prevent sharing demo race
    if (controller.currentRace != null &&
        DemoRaceGenerator.isDemoRace(controller.currentRace!)) {
      DialogUtils.showMessageDialog(
        context,
        title: 'Practice Race',
        message:
            'Times from the practice race cannot be shared. Get the real race '
            'from your coach, then time it.',
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
  }

  Future<void> _handleLogButtonPress(BuildContext context) async {
    final error = await controller.handleLogButtonPress();
    if (error != null && context.mounted) {
      DialogUtils.showErrorDialog(context, message: error.userMessage);
    }
  }
}

/// Asks before stopping, since a stopped clock stops logging finishes.
Future<void> confirmStopTimer(
    BuildContext context, TimingController controller) async {
  final confirmed = await DialogUtils.showConfirmationDialog(
    context,
    title: 'Stop the Race?',
    content: 'Stop the clock once every runner has finished. You can resume '
        'if you stop too early.',
    confirmText: 'Stop',
    cancelText: 'Keep Running',
    destructive: true,
  );
  if (confirmed && context.mounted) {
    controller.stopRace();
  }
}
