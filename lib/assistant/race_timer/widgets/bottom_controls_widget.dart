import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
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
          _buildMainControlButton(),
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

  Widget _buildMainControlButton() {
    // Show undo button if last record is a conflict, otherwise show confirm button
    if (controller.isLastRecordConflict) {
      return _buildControlButton(
        icon: Icons.undo,
        color: Colors.grey[700]!,
        onTap: controller.undoLastConflict,
      );
    } else {
      return _buildControlButton(
        icon: Icons.check,
        color: Colors.green,
        onTap: controller.confirmTimes,
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
            onTap: controller.addMissingTime,
            child: Text(
              '+ (Add finish time)',
              style: AppTypography.bodySemibold,
            ),
          ),
          PopupMenuItem<void>(
            onTap: controller.removeExtraTime,
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
}
