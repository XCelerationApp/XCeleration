import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_border_radius.dart';
import 'action_button.dart';

/// Toggle button that changes appearance based on selection state
class ToggleButton extends ActionButton {
  const ToggleButton({
    super.key,
    required super.text,
    super.onPressed,
    required super.icon,
    super.borderRadius = AppBorderRadius.md,
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
