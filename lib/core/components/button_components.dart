import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/typography.dart';
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

    final effectiveBorderRadius = borderRadius ?? 12.0;

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
                    color:
                        ColorUtils.withOpacity(effectiveBackgroundColor, 0.3),
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
                          ColorUtils.withOpacity(AppColors.primaryColor, 0.3),
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
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
      case ButtonSize.large:
      case ButtonSize.fullWidth:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
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

/// Primary action button with default styling
class PrimaryButton extends ActionButton {
  const PrimaryButton({
    super.key,
    required super.text,
    super.onPressed,
    super.icon,
    super.borderRadius = 12.0,
    super.size = ButtonSize.medium,
    super.elevation = 2.0,
    super.iconLeading = true,
    super.isEnabled = true,
    super.padding,
    super.iconSize,
    super.fontSize,
    super.fontWeight,
  }) : super(
          isPrimary: true,
          backgroundColor: AppColors.primaryColor,
          textColor: Colors.white,
        );
}

/// Secondary action button with default styling (outlined)
class SecondaryButton extends ActionButton {
  const SecondaryButton({
    super.key,
    required super.text,
    super.onPressed,
    super.icon,
    super.borderRadius = 12.0,
    super.size = ButtonSize.medium,
    super.elevation = 0.0,
    super.iconLeading = true,
    super.isEnabled = true,
    super.padding,
    super.iconSize,
    super.fontSize,
    super.fontWeight,
    super.height,
  }) : super(
          isPrimary: false,
          backgroundColor: Colors.white,
          textColor: AppColors.primaryColor,
        );
}

/// Full width action button for flow-type actions
class FullWidthButton extends ActionButton {
  const FullWidthButton({
    super.key,
    required super.text,
    super.onPressed,
    super.icon,
    super.backgroundColor,
    super.textColor,
    super.borderRadius = 16.0,
    super.isSelected = false,
    super.isPrimary = true,
    super.elevation = 2.0,
    super.iconLeading = true,
    super.isEnabled = true,
    super.iconSize,
    super.fontSize,
    super.fontWeight,
  }) : super(
          size: ButtonSize.fullWidth,
          padding: const EdgeInsets.symmetric(vertical: 16),
        );
}

/// Icon-only button for compact UI elements
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final double iconSize;
  final double elevation;
  final bool isEnabled;

  const CircleIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 48.0,
    this.iconSize = 24.0,
    this.elevation = 1.0,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ?? Colors.white;
    final effectiveIconColor = iconColor ?? AppColors.primaryColor;

    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: elevation > 0
              ? [
                  BoxShadow(
                    color: ColorUtils.withOpacity(Colors.black, 0.1),
                    spreadRadius: 0,
                    blurRadius: elevation * 2,
                    offset: elevation > 0 ? const Offset(0, 2) : Offset.zero,
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: isEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: effectiveBackgroundColor,
            foregroundColor: effectiveIconColor,
            disabledBackgroundColor:
                ColorUtils.withOpacity(effectiveBackgroundColor, 0.5),
            disabledForegroundColor:
                ColorUtils.withOpacity(effectiveIconColor, 0.5),
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
            elevation: 0,
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: effectiveIconColor,
          ),
        ),
      ),
    );
  }
}

/// Toggle button that changes appearance based on selection state
class ToggleButton extends ActionButton {
  const ToggleButton({
    super.key,
    required super.text,
    super.onPressed,
    required super.icon,
    super.borderRadius = 12.0,
    required super.isSelected,
    super.size = ButtonSize.medium,
    super.elevation = 2.0,
    super.iconLeading = true,
    super.isEnabled = true,
    super.padding,
    super.iconSize,
    super.fontSize,
    super.fontWeight,
  }) : super(
          isPrimary: isSelected,
          backgroundColor: isSelected ? AppColors.primaryColor : Colors.white,
          textColor: isSelected ? Colors.white : AppColors.primaryColor,
        );
}

/// Circular button with custom background and border
class CircularButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Color color;
  final double fontSize;
  final FontWeight? fontWeight;
  final double elevation;

  const CircularButton({
    required this.onPressed,
    required this.text,
    required this.color,
    this.fontSize = 20,
    this.fontWeight,
    this.elevation = 0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 70,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: AppColors.backgroundColor,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color,
              spreadRadius: 2,
              blurRadius: elevation > 0 ? 4 : 0,
              offset: elevation > 0 ? const Offset(0, 2) : Offset.zero,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            elevation: 0,
          ),
          child: Text(
            text,
            style: fontSize <= 16
                ? AppTypography.bodySemibold.copyWith(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                  )
                : AppTypography.titleSemibold.copyWith(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                  ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

/// Rounded rectangle button with custom width, height, and color
class RoundedRectangleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Color color;
  final double fontSize;
  final double width;
  final double height;

  const RoundedRectangleButton({
    this.onPressed,
    required this.text,
    required this.color,
    required this.width,
    required this.height,
    this.fontSize = 20,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          color: color,
          border: Border.all(
            color: AppColors.backgroundColor,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color,
              spreadRadius: 2,
            ),
          ],
          borderRadius: BorderRadius.all(Radius.circular(40)),
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(40)),
            ),
            padding: EdgeInsets.zero,
            elevation: 0,
          ),
          child: Text(
            text,
            style: fontSize <= 16
                ? AppTypography.bodySemibold.copyWith(
                    color: Colors.white,
                    fontSize: fontSize,
                  )
                : AppTypography.titleSemibold.copyWith(
                    color: Colors.white,
                    fontSize: fontSize,
                  ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

/// Shared ActionButton component that consolidates multiple ActionButton implementations
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
        borderRadius: borderRadius ?? 12,
        elevation: elevation ?? (isSelected ? 3 : 1),
        fontSize: fontSize ?? 12,
        fontWeight: fontWeight ?? FontWeight.w600,
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        padding:
            padding ?? const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        borderRadius: borderRadius ?? 12,
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
        borderRadius: borderRadius ?? 12,
        elevation: elevation ?? 4,
        fontSize: fontSize ?? 16,
        fontWeight: fontWeight ?? FontWeight.w600,
        isEnabled: computedEnabled,
      );
    }
  }
}
