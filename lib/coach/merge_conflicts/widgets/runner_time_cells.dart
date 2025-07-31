import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';

/// Helper widget for displaying a time string in cell style.
class TimeDisplay extends StatelessWidget {
  final String time;
  final FontWeight fontWeight;
  final double letterSpacing;
  final Color color;
  const TimeDisplay({
    super.key,
    required this.time,
    this.fontWeight = FontWeight.w700,
    this.letterSpacing = -0.2,
    this.color = AppColors.darkColor,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      time.isNotEmpty ? time : '—',
      style: AppTypography.smallBodySemibold.copyWith(
        color: color,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
      ),
    );
  }
}

/// Helper for action icons (e.g., add, remove)
class CellActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  const CellActionIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

/// Confirmed runner time cell (was ConfirmedTime)
class ConfirmedRunnerTimeCell extends StatelessWidget {
  final String time;
  const ConfirmedRunnerTimeCell({super.key, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TimeDisplay(time: time),
        ],
      ),
    );
  }
}

class ExtraTimeCell extends StatelessWidget {
  final String time;
  final void Function() onRemoveExtraTime;

  const ExtraTimeCell({
    super.key,
    required this.time,
    required this.onRemoveExtraTime,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 2),
        Expanded(
          child: TimeDisplay(time: time),
        ),
        CellActionIcon(
          icon: Icons.close,
          tooltip: 'Remove extra time',
          onPressed: () => onRemoveExtraTime(),
        ),
      ],
    );
  }
}

class MissingTimeCell extends StatelessWidget {
  final TextEditingController controller;
  final String time;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onChanged;

  const MissingTimeCell({
    super.key,
    required this.controller,
    required this.time,
    required this.onSubmitted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (time == 'TBD') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Enter missing time',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: OutlineInputBorder(),
              ),
              style: AppTypography.smallBodySemibold.copyWith(
                color: AppColors.darkColor,
              ),
              onSubmitted: onSubmitted,
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: TimeDisplay(time: time),
          ),
          CellActionIcon(
            icon: Icons.add_circle_outline,
            tooltip: 'Enter manual time',
            onPressed: () => onChanged(controller.text),
          ),
        ],
      );
    }
  }
}
