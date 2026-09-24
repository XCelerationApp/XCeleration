import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/components/dialog_utils.dart';
import '../../shared/widgets/race_day_controls.dart';
import '../controller/timing_controller.dart';

/// The two count checks above Log Finish. When there is a break in the
/// runners, the Timer compares counts with the Bib Recorder and taps one.
class BottomControlsWidget extends StatelessWidget {
  final TimingController controller;

  const BottomControlsWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildMainControlButton(context)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildAdjustTimesButton(context)),
      ],
    );
  }

  Widget _buildMainControlButton(BuildContext context) {
    // Show undo button if last record is a conflict, otherwise show confirm button
    if (controller.isLastRecordUndoable) {
      return RaceDayButton(
        label: 'Undo',
        icon: Icons.undo,
        color: AppColors.mediumColor,
        onPressed: () => _handleUndoLastConflict(context),
      );
    }
    // Pressed once the Bib Recorder has the same number of runners.
    return RaceDayButton(
      label: 'Counts match',
      icon: Icons.check,
      color: Colors.green.shade700,
      onPressed: () => _handleConfirmTimes(context),
    );
  }

  Widget _buildAdjustTimesButton(BuildContext context) {
    return PopupMenuButton<void>(
      tooltip: 'Counts differ?',
      position: PopupMenuPosition.over,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<void>>[
        PopupMenuItem<void>(
          onTap: () => _handleAddMissingTime(context),
          child: Text(
            'I missed a runner (add a time)',
            style: AppTypography.bodySemibold,
          ),
        ),
        PopupMenuItem<void>(
          onTap: () => _handleRemoveExtraTime(context),
          child: Text(
            'I tapped an extra time (remove one)',
            style: AppTypography.bodySemibold,
          ),
        ),
      ],
      // The menu opens on tap; the button only draws the outline.
      child: const IgnorePointer(
        child: RaceDayButton(
          label: 'Counts differ?',
          icon: Icons.unfold_more,
          color: AppColors.darkColor,
          onPressed: _noop,
        ),
      ),
    );
  }

  Future<void> _handleUndoLastConflict(BuildContext context) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context,
      title: controller.undoDialogTitle,
      content: controller.undoDialogContent,
    );
    if (confirmed && context.mounted) {
      controller.doUndoLastConflict();
    }
  }

  Future<void> _handleConfirmTimes(BuildContext context) async {
    final error = controller.confirmTimes();
    if (error != null && context.mounted) {
      DialogUtils.showErrorDialog(context, message: error.userMessage);
    }
  }

  Future<void> _handleAddMissingTime(BuildContext context) async {
    final error = await controller.addMissingTime();
    if (error != null && context.mounted) {
      DialogUtils.showErrorDialog(context, message: error.userMessage);
    }
  }

  Future<void> _handleRemoveExtraTime(BuildContext context) async {
    final result = await controller.removeExtraTime();
    if (!context.mounted) return;
    switch (result) {
      case RemoveExtraTimeOk():
        return;
      case RemoveExtraTimeError(:final error):
        DialogUtils.showErrorDialog(context, message: error.userMessage);
      case RemoveExtraTimeConfirmRequired(:final offBy):
        final confirmed = await DialogUtils.showConfirmationDialog(
          context,
          title: 'Confirm Deletion',
          content:
              'This will delete the last $offBy finish times, are you sure you want to continue?',
        );
        if (confirmed && context.mounted) {
          controller.executeRemoveExtraTimeDeletion();
        }
    }
  }
}

void _noop() {}
