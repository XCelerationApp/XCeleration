import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_border_radius.dart';
import '../theme/app_opacity.dart';
import '../theme/app_spacing.dart';
import 'package:xceleration/core/utils/color_utils.dart';

/// Size presets for buttons
enum ButtonSize {
  small,
  medium,
  large,
  fullWidth,
}

/// Base class for all action buttons
class ActionButton extends StatelessWidget {
  final double? height;
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? borderRadius;
  final bool isSelected;
  final bool isPrimary;
  final ButtonSize size;
  final double elevation;
  final bool iconLeading;
  final bool isEnabled;
  final EdgeInsetsGeometry? padding;
  final double? iconSize;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? borderColor;

  const ActionButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.borderRadius,
    this.isSelected = false,
    this.isPrimary = true,
    this.size = ButtonSize.medium,
    this.elevation = 2.0,
    this.iconLeading = true,
    this.isEnabled = true,
    this.padding,
    this.iconSize,
    this.fontSize,
    this.fontWeight,
    this.height,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool effectiveEnabled = isEnabled;

    // Base colors as if enabled
    Color effectiveBackgroundColor =
        backgroundColor ?? (isPrimary ? AppColors.primaryColor : Colors.white);
    Color effectiveTextColor =
        textColor ?? (isPrimary ? Colors.white : AppColors.primaryColor);
    Color? effectiveBorderColor = borderColor;

    // Override colors when disabled for consistent grey appearance
    if (!effectiveEnabled) {
      effectiveBackgroundColor = Colors.grey.shade400;
      effectiveTextColor = Colors.white54;
      effectiveBorderColor = Colors.grey.shade400;
    }

    final effectiveBorderRadius = borderRadius ?? AppBorderRadius.md;

    final effectiveIconSize = iconSize ?? _getIconSizeForButtonSize(size);
    final effectiveFontSize = fontSize ?? _getFontSizeForButtonSize(size);
    final effectiveFontWeight = fontWeight ?? FontWeight.w500;

    // Get dimensions based on size
    Size buttonSize = _getSizeForButtonSize(size);
    EdgeInsetsGeometry buttonPadding =
        padding ?? _getPaddingForButtonSize(size);

    // For full width buttons, we need to override the width
    final Widget buttonContent = size == ButtonSize.fullWidth
        ? SizedBox(
            width: double.infinity,
            child: _buildButtonContent(effectiveTextColor, effectiveIconSize,
                effectiveFontSize, effectiveFontWeight),
          )
        : _buildButtonContent(effectiveTextColor, effectiveIconSize,
            effectiveFontSize, effectiveFontWeight);

    return SizedBox(
      width: size == ButtonSize.fullWidth ? double.infinity : buttonSize.width,
      child: Container(
        decoration: BoxDecoration(
          color: effectiveBorderColor ?? effectiveBackgroundColor,
          borderRadius: BorderRadius.circular(effectiveBorderRadius),
          boxShadow: elevation > 0
              ? [
                  BoxShadow(
                    color: ColorUtils.withOpacity(
                        effectiveBackgroundColor, AppOpacity.strong),
                    spreadRadius: 0,
                    blurRadius: elevation * 2,
                    offset: Offset(0, elevation),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: effectiveEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: effectiveBackgroundColor,
            foregroundColor: effectiveTextColor,
            disabledBackgroundColor: Colors.grey.shade400,
            disabledForegroundColor: Colors.white54,
            elevation: 0,
            padding: buttonPadding,
            minimumSize: Size(0, height ?? buttonSize.height),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(effectiveBorderRadius),
              side: isPrimary
                  ? BorderSide.none
                  : BorderSide(
                      color: effectiveBorderColor ??
                          ColorUtils.withOpacity(
                              AppColors.primaryColor, AppOpacity.strong),
                      width: 1,
                    ),
            ),
          ),
          child: buttonContent,
        ),
      ),
    );
  }

  Widget _buildButtonContent(Color textColor, double iconSize, double fontSize,
      FontWeight fontWeight) {
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (iconLeading) ...[
            Icon(icon, size: iconSize, color: textColor),
            SizedBox(width: iconSize * 0.3),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: fontSize,
                fontWeight: fontWeight,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          if (!iconLeading) ...[
            SizedBox(width: iconSize * 0.3),
            Icon(icon, size: iconSize, color: textColor),
          ],
        ],
      );
    } else {
      return Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      );
    }
  }

  Size _getSizeForButtonSize(ButtonSize size) {
    switch (size) {
      case ButtonSize.small:
        return const Size(120, 36);
      case ButtonSize.medium:
        return const Size(160, 48);
      case ButtonSize.large:
        return const Size(200, 56);
      case ButtonSize.fullWidth:
        return const Size(double.infinity, 56);
    }
  }

  EdgeInsetsGeometry _getPaddingForButtonSize(ButtonSize size) {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs);
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10);
      case ButtonSize.large:
      case ButtonSize.fullWidth:
        return const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.lg);
    }
  }

  double _getIconSizeForButtonSize(ButtonSize size) {
    switch (size) {
      case ButtonSize.small:
        return 16.0;
      case ButtonSize.medium:
        return 18.0;
      case ButtonSize.large:
      case ButtonSize.fullWidth:
        return 24.0;
    }
  }

  double _getFontSizeForButtonSize(ButtonSize size) {
    switch (size) {
      case ButtonSize.small:
        return 12.0;
      case ButtonSize.medium:
        return 14.0;
      case ButtonSize.large:
      case ButtonSize.fullWidth:
        return 16.0;
    }
  }
}
