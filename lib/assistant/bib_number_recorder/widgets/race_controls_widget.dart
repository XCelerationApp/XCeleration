import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../shared/widgets/race_day_controls.dart';
import '../controller/bib_number_controller.dart';

/// The bottom of the Bib Recorder while the number pad is down: Start
/// Recording before the race, a big Add Bib during it, and Share Bibs after.
class RaceControlsWidget extends StatelessWidget {
  final BibNumberController controller;
  final VoidCallback onShare;

  const RaceControlsWidget({
    super.key,
    required this.controller,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    if (controller.currentRace == null) return const SizedBox.shrink();

    if (!controller.raceStopped) {
      return BigActionButton(
        key: const ValueKey('add_bib_button'),
        label: 'Add Bib',
        sublabel: 'Runner ${controller.bibRecords.length + 1}',
        icon: Icons.add_rounded,
        color: AppColors.primaryColor,
        onPressed: controller.addBib,
      );
    }

    if (controller.bibRecords.isEmpty) {
      return BigActionButton(
        key: const ValueKey('start_recording_button'),
        label: 'Start Recording',
        sublabel: 'Opens the keypad for the first runner',
        icon: Icons.play_arrow_rounded,
        color: Colors.green.shade600,
        onPressed: controller.addBibStartingRace,
      );
    }

    return Row(
      children: [
        Expanded(
          child: RaceDayButton(
            label: 'Resume',
            icon: Icons.play_arrow_rounded,
            color: Colors.green.shade700,
            height: 64,
            onPressed: () => controller.raceStopped = false,
          ),
        ),
        if (controller.countNonEmptyBibNumbers() > 0) ...[
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: RaceDayButton(
              label: 'Share Bibs',
              icon: Icons.ios_share,
              color: AppColors.primaryColor,
              filled: true,
              height: 64,
              onPressed: onShare,
            ),
          ),
        ],
      ],
    );
  }
}
