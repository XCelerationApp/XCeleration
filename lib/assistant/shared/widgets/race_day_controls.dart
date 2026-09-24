import 'package:flutter/material.dart';

import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

/// The one button a volunteer presses over and over during a race — Log
/// Finish, Add Bib — full width and at the bottom, where a thumb rests.
///
/// [onTapDown] fires the moment a finger lands, before it lifts, so a time
/// is taken when the runner crosses rather than a moment later. Use
/// [onPressed] for anything that should wait for the finger to lift.
class BigActionButton extends StatefulWidget {
  const BigActionButton({
    super.key,
    required this.label,
    required this.color,
    this.sublabel,
    this.icon,
    this.onPressed,
    this.onTapDown,
    this.height = 88,
  });

  final String label;
  final String? sublabel;
  final IconData? icon;
  final Color color;
  final VoidCallback? onPressed;
  final VoidCallback? onTapDown;
  final double height;

  @override
  State<BigActionButton> createState() => _BigActionButtonState();
}

class _BigActionButtonState extends State<BigActionButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null || widget.onTapDown != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final color = _enabled ? widget.color : AppColors.lightColor;
    final foreground = _enabled ? Colors.white : AppColors.mediumColor;
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled
            ? (_) {
                _setPressed(true);
                widget.onTapDown?.call();
              }
            : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          constraints: BoxConstraints(minHeight: widget.height),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: _pressed ? Color.lerp(color, Colors.black, 0.15) : color,
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: foreground, size: 30),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: AppTypography.titleLarge.copyWith(
                          color: foreground, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (widget.sublabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  widget.sublabel!,
                  textAlign: TextAlign.center,
                  style: AppTypography.smallBodySemibold.copyWith(
                      color: foreground.withValues(alpha: 0.85)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A plain outlined button that sits beside or above a [BigActionButton]:
/// Resume, Counts match, Undo.
class RaceDayButton extends StatelessWidget {
  const RaceDayButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.darkColor,
    this.filled = false,
    this.height = 56,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final bool filled;
  final double height;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = (filled
            ? FilledButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white)
            : OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(
                    color: color.withValues(alpha: AppOpacity.solid)),
              ))
        .copyWith(
      minimumSize: WidgetStatePropertyAll(Size(0, height)),
      padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.md)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg))),
      textStyle: WidgetStatePropertyAll(AppTypography.bodySemibold),
    );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22),
          const SizedBox(width: AppSpacing.sm),
        ],
        // Shrinks rather than wrapping mid-word ("Resum-e") on a narrow
        // phone or at a large text size.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1, textAlign: TextAlign.center),
          ),
        ),
      ],
    );
    return filled
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}

/// A slim line saying what the race is doing — Ready, Recording, Stopped —
/// with the count so far and, while it runs, a small Stop button kept away
/// from the big button at the bottom.
class RaceDayStatusBar extends StatelessWidget {
  const RaceDayStatusBar({
    super.key,
    required this.status,
    required this.color,
    required this.count,
    this.onStop,
    this.trailing,
  });

  final String status;
  final Color color;

  /// Such as '12 bibs'.
  final String count;

  /// Shown as a Stop button while the race runs.
  final VoidCallback? onStop;

  /// Anything else to put under the status, such as the race clock.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  status,
                  style: AppTypography.bodySemibold.copyWith(color: color),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('· $count',
                  style: AppTypography.bodySemibold
                      .copyWith(color: AppColors.mediumColor)),
              const Spacer(),
              if (onStop != null)
                OutlinedButton(
                  onPressed: onStop,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.redColor,
                    side: BorderSide(
                        color: AppColors.redColor
                            .withValues(alpha: AppOpacity.solid)),
                    minimumSize: const Size(72, 40),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppBorderRadius.full)),
                  ),
                  child: Text('Stop', style: AppTypography.bodySemibold),
                ),
            ],
          ),
          ?trailing,
        ],
      ),
    );
  }
}
