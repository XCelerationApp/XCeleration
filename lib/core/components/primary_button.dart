import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_border_radius.dart';
import '../theme/app_spacing.dart';
import 'action_button.dart';

/// Primary action button with default styling
class PrimaryButton extends ActionButton {
  const PrimaryButton({
    super.key,
    required super.text,
    super.onPressed,
    super.icon,
    super.borderRadius = AppBorderRadius.md,
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
    super.borderRadius = AppBorderRadius.md,
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
    super.borderRadius = AppBorderRadius.lg,
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
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        );
}
