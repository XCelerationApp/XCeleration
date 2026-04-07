import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Full-width pill button used in the race mode action area.
class RaceActionButton extends StatefulWidget {
  const RaceActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.backgroundColor,
    this.borderColor,
  });

  final String label;
  final Color color;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  State<RaceActionButton> createState() => _RaceActionButtonState();
}

class _RaceActionButtonState extends State<RaceActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: _pressed
              ? (widget.backgroundColor ?? widget.color)
                  .withValues(alpha: AppOpacity.solid)
              : widget.backgroundColor ?? widget.color,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: widget.borderColor != null
              ? Border.all(color: widget.borderColor!)
              : null,
        ),
        child: Center(
          child: Text(
            widget.label,
            style: AppTypography.smallBodySemibold.copyWith(
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented toggle chip for switching between voice and manual input modes.
class RaceToggleChip extends StatelessWidget {
  const RaceToggleChip({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm - 1,
        ),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? AppColors.darkColor : AppColors.mediumColor,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.darkColor : AppColors.mediumColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two-segment voice / manual input mode toggle bar.
class RaceInputModeToggle extends StatelessWidget {
  const RaceInputModeToggle({
    super.key,
    required this.isManualMode,
    required this.onSwitchToVoice,
    required this.onSwitchToManual,
  });

  final bool isManualMode;
  final VoidCallback onSwitchToVoice;
  final VoidCallback onSwitchToManual;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: RaceToggleChip(
              icon: Icons.mic,
              label: 'Voice',
              selected: !isManualMode,
              onTap: onSwitchToVoice,
            ),
          ),
          Expanded(
            child: RaceToggleChip(
              icon: Icons.keyboard_alt_outlined,
              label: 'Manual',
              selected: isManualMode,
              onTap: onSwitchToManual,
            ),
          ),
        ],
      ),
    );
  }
}
