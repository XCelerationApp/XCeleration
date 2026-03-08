import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_border_radius.dart';
import '../theme/app_spacing.dart';
import 'action_button.dart';
import 'primary_button.dart';
import 'toggle_button.dart';

/// Factory-style widget that routes to [ToggleButton], [ActionButton], or [PrimaryButton]
/// based on the supplied parameters.
///
/// Design note: this is a widget rather than a Dart factory constructor because it
/// selects between sibling types ([ToggleButton], [PrimaryButton]) that cannot all be
/// returned from a single factory constructor while preserving type safety and
/// const-constructibility. The current widget approach keeps the routing logic
/// explicit, named, and easily discoverable.
class SharedActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isSelected;
  final bool isPrimary;
  // Optional explicit enable flag. If null, falls back to (onPressed != null)
  final bool? isEnabled;
  final double? fontSize;
  final FontWeight? fontWeight;
  final double? borderRadius;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double? elevation;
  final double? height;
  final ButtonSize? size;

  const SharedActionButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isSelected = false,
    this.isPrimary = true,
    this.isEnabled,
    this.fontSize,
    this.fontWeight,
    this.borderRadius,
    this.padding,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.elevation,
    this.height,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final bool computedEnabled = isEnabled ?? (onPressed != null);
    if (isSelected || (!isPrimary && icon != null)) {
      // Use ToggleButton for selected states or secondary buttons with icons
      return ToggleButton(
        text: text,
        icon: icon,
        isSelected: isSelected,
        onPressed: onPressed,
        isEnabled: computedEnabled,
        borderRadius: borderRadius ?? AppBorderRadius.md,
        elevation: elevation ?? (isSelected ? 3 : 1),
        fontSize: fontSize ?? 12,
        fontWeight: fontWeight ?? FontWeight.w600,
        padding: padding ??
            const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      );
    } else if (height != null ||
        backgroundColor != null ||
        borderColor != null) {
      // Use ActionButton for custom styled buttons
      return ActionButton(
        height: height ?? 50,
        text: text,
        icon: icon,
        iconSize: 18,
        fontSize: fontSize ?? 16,
        textColor: textColor ??
            (isPrimary && computedEnabled
                ? Colors.white
                : AppColors.mediumColor),
        backgroundColor: backgroundColor ??
            (isPrimary && computedEnabled
                ? AppColors.primaryColor
                : AppColors.backgroundColor),
        borderColor: borderColor ??
            (isPrimary && computedEnabled
                ? AppColors.primaryColor
                : AppColors.mediumColor),
        fontWeight: fontWeight ?? FontWeight.w500,
        padding: padding ??
            const EdgeInsets.symmetric(
                vertical: AppSpacing.sm, horizontal: AppSpacing.lg),
        borderRadius: borderRadius ?? AppBorderRadius.md,
        isPrimary: isPrimary,
        onPressed: onPressed,
        isEnabled: computedEnabled,
      );
    } else {
      // Use PrimaryButton for simple primary actions
      return PrimaryButton(
        text: text,
        onPressed: onPressed,
        icon: icon,
        size: size ?? ButtonSize.medium,
        borderRadius: borderRadius ?? AppBorderRadius.md,
        elevation: elevation ?? 4,
        fontSize: fontSize ?? 16,
        fontWeight: fontWeight ?? FontWeight.w600,
        isEnabled: computedEnabled,
      );
    }
  }
}
