import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/components/dialog_utils.dart';
import '../../shared/widgets/race_day_controls.dart';
import '../controller/timing_controller.dart';

/// The two count checks above Log Finish. When there is a break in the
/// runners, the Timer compares counts with the Bib Recorder and taps one.
///
/// "Counts differ?" swaps the row for its two answers in place, rather
/// than a menu: a menu lay over Log Finish, and a tap on Log Finish while
/// it was open only closed it, so a runner finishing then was never logged.
class BottomControlsWidget extends StatefulWidget {
  final TimingController controller;

  const BottomControlsWidget({
    super.key,
    required this.controller,
  });

  @override
  State<BottomControlsWidget> createState() => _BottomControlsWidgetState();
}

class _BottomControlsWidgetState extends State<BottomControlsWidget> {
  bool _choosing = false;

  TimingController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    if (_choosing) {
      return Row(
        children: [
          Expanded(
            child: RaceDayButton(
              key: const ValueKey('timer_missed_runner'),
              label: 'Missed one',
              icon: Icons.add,
              color: AppColors.darkColor,
              onPressed: () {
                setState(() => _choosing = false);
                _handleAddMissingTime(context);
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: RaceDayButton(
              key: const ValueKey('timer_extra_tap'),
              label: 'Extra tap',
              icon: Icons.remove,
              color: AppColors.darkColor,
              onPressed: () {
                setState(() => _choosing = false);
                _handleRemoveExtraTime(context);
              },
            ),
          ),
          IconButton(
            key: const ValueKey('timer_counts_cancel'),
            tooltip: 'Cancel',
            icon: const Icon(Icons.close, color: AppColors.mediumColor),
            onPressed: () => setState(() => _choosing = false),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: _buildMainControlButton(context)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: RaceDayButton(
            key: const ValueKey('timer_counts_differ'),
            label: 'Counts differ?',
            icon: Icons.unfold_more,
            color: AppColors.darkColor,
            onPressed: () => setState(() => _choosing = true),
          ),
        ),
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

