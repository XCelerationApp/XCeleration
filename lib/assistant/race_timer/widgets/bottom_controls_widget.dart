import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../../../core/components/dialog_utils.dart';
import '../controller/timing_controller.dart';
import 'package:xceleration/core/utils/color_utils.dart';

class BottomControlsWidget extends StatelessWidget {
  final TimingController controller;

  const BottomControlsWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.withOpacity(Colors.black, 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMainControlButton(context),
          Container(
            height: 30,
            width: 1,
            color: ColorUtils.withOpacity(Colors.grey, 0.3),
          ),
          _buildAdjustTimesButton(context),
        ],
      ),
    );
  }

  Widget _buildMainControlButton(BuildContext context) {
    // Show undo button if last record is a conflict, otherwise show confirm button
    if (controller.isLastRecordUndoable) {
      return _buildControlButton(
        icon: Icons.undo,
        color: Colors.grey[700]!,
        onTap: () => _handleUndoLastConflict(context),
      );
    } else {
      return _buildControlButton(
        icon: Icons.check,
        color: Colors.green,
        onTap: () => _handleConfirmTimes(context),
      );
    }
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ColorUtils.withOpacity(color, 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 30,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAdjustTimesButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: PopupMenuButton<void>(
        itemBuilder: (BuildContext context) => <PopupMenuEntry<void>>[
          PopupMenuItem<void>(
            onTap: () => _handleAddMissingTime(context),
            child: Text(
              '+ (Add finish time)',
              style: AppTypography.bodySemibold,
            ),
          ),
          PopupMenuItem<void>(
            onTap: () => _handleRemoveExtraTime(context),
            child: Text(
              '- (Remove finish time)',
              style: AppTypography.bodySemibold,
            ),
          ),
        ],
        child: Text(
          'Adjust # of times',
          style: AppTypography.titleRegular,
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
