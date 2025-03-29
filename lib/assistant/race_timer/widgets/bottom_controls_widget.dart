import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';

class BottomControlsWidget extends StatelessWidget {
  final VoidCallback onConfirmRunnerNumber;
  final VoidCallback onMissingRunnerTime;
  final VoidCallback onExtraRunnerTime;
  final VoidCallback? onUndoLastConflict;
  final bool hasUndoableConflict;

  const BottomControlsWidget({
    super.key,
    required this.onConfirmRunnerNumber,
    required this.onMissingRunnerTime,
    required this.onExtraRunnerTime,
    this.onUndoLastConflict,
    required this.hasUndoableConflict,
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.check,
            color: Colors.green,
            onTap: onConfirmRunnerNumber,
          ),
          Container(
            height: 30,
            width: 1,
            color: Colors.grey.withOpacity(0.3),
          ),
          _buildAdjustTimesButton(context),
          if (hasUndoableConflict && onUndoLastConflict != null)
            _buildControlButton(
              icon: Icons.undo,
              color: AppColors.mediumColor,
              onTap: onUndoLastConflict!,
            ),
        ],
      ),
    );
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
          color: color.withOpacity(0.1),
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
            onTap: onMissingRunnerTime,
            child: Text(
              '+ (Add finish time)',
              style: AppTypography.bodyRegular.copyWith(fontSize: 17),
            ),
          ),
          PopupMenuItem<void>(
            onTap: onExtraRunnerTime,
            child: Text(
              '- (Remove finish time)',
              style: AppTypography.bodyRegular.copyWith(fontSize: 17),
            ),
          ),
        ],
        child: Text(
          'Adjust # of times',
          style: AppTypography.bodyRegular.copyWith(fontSize: 20),
        ),
      ),
    );
  }
}
