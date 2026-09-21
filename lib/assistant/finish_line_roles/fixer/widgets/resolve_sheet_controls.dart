import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// "Create new runner" button shown in the search flow of the resolve sheet.
class CreateRunnerButton extends StatefulWidget {
  const CreateRunnerButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<CreateRunnerButton> createState() => _CreateRunnerButtonState();
}

class _CreateRunnerButtonState extends State<CreateRunnerButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const amber = AppColors.warningAmber;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: _pressed
              ? amber.withValues(alpha: AppOpacity.medium)
              : amber.withValues(alpha: AppOpacity.subtle),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(
            color: amber.withValues(alpha: AppOpacity.medium),
          ),
        ),
        child: Center(
          child: Text(
            'Create new runner',
            style: AppTypography.smallBodySemibold.copyWith(color: amber),
          ),
        ),
      ),
    );
  }
}

/// "Leave for coach" button shown at the bottom of the search flow.
class LeaveForCoachButton extends StatefulWidget {
  const LeaveForCoachButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<LeaveForCoachButton> createState() => _LeaveForCoachButtonState();
}

class _LeaveForCoachButtonState extends State<LeaveForCoachButton> {
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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md - 2),
        decoration: BoxDecoration(
          color: _pressed ? AppColors.surfaceColor : Colors.white,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Center(
          child: Text(
            'Leave for coach',
            style: AppTypography.smallBodySemibold.copyWith(
              color: AppColors.mediumColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Labelled text field used in the create-runner form.
class ResolveFormField extends StatelessWidget {
  const ResolveFormField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.smallBodySemibold.copyWith(
              color: AppColors.darkColor,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: AppTypography.smallBodyRegular.copyWith(
              color: AppColors.darkColor,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.smallBodyRegular.copyWith(
                color: AppColors.lightColor,
              ),
              filled: true,
              fillColor: AppColors.backgroundColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
                borderSide: const BorderSide(
                  color: AppColors.primaryColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Add Runner" submit button for the create-runner form.
class AddRunnerButton extends StatelessWidget {
  const AddRunnerButton({
    super.key,
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg - 2),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [AppColors.primaryColor, AppColors.primaryGradientEnd],
                )
              : null,
          color: enabled ? null : AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primaryColor
                        .withValues(alpha: AppOpacity.medium),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            'Add Runner',
            style: AppTypography.smallBodySemibold.copyWith(
              color: enabled ? Colors.white : AppColors.mediumColor,
            ),
          ),
        ),
      ),
    );
  }
}
