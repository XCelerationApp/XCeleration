import 'package:flutter/material.dart';
import 'package:xceleration/core/components/textfield_utils.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../controller/race_screen_controller.dart';
import '../controller/race_form_state.dart';

class InlineEditableField extends StatelessWidget {
  final RaceScreenController controller;
  final RaceField field;
  final String label;
  final IconData icon;
  final TextEditingController textController;
  final String hint;
  final String? error;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final Widget? customEditWidget;
  final String Function()? getDisplayValue;

  /// How many lines the saved value may take, such as 2 for an address.
  final int maxDisplayLines;

  const InlineEditableField({
    super.key,
    required this.controller,
    required this.field,
    required this.label,
    required this.icon,
    required this.textController,
    required this.hint,
    this.error,
    this.keyboardType,
    this.suffixIcon,
    this.customEditWidget,
    this.getDisplayValue,
    this.maxDisplayLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = getDisplayValue?.call() ?? textController.text;
    final isEmpty =
        displayValue.isEmpty ||
        displayValue == 'Not set' ||
        displayValue == '0 ';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Builder(
        builder: (context) {
          // Simple synchronous check - no async needed
          final isEditable = controller.form.shouldShowAsEditable(
            field,
            controller.race,
            controller.canEdit,
          );

          return isEditable
              ? _buildEditableMode(context)
              : _buildViewMode(context, displayValue, isEmpty);
        },
      ),
    );
  }

  Widget _buildViewMode(
    BuildContext context,
    String displayValue,
    bool isEmpty,
  ) {
    // The whole row edits, not just the small pencil.
    return InkWell(
      onTap: controller.canEdit
          ? () => controller.form.startEditing(field)
          : null,
      borderRadius: BorderRadius.circular(AppBorderRadius.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: AppOpacity.light),
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
            ),
            child: Icon(icon, color: AppColors.primaryColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.mediumColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isEmpty ? 'Not set' : displayValue,
                  style: AppTypography.bodySemibold.copyWith(
                    color: isEmpty
                        ? AppColors.mediumColor
                        : AppColors.darkColor,
                  ),
                  maxLines: maxDisplayLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Builder(
            builder: (context) {
              final canEdit = controller.canEdit;
              if (canEdit) {
                return Row(
                  children: [
                    const SizedBox(width: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Icon(
                        Icons.edit,
                        color: AppColors.primaryColor,
                        size: 20,
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEditableMode(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(
                  alpha: AppOpacity.light,
                ),
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
              ),
              child: Icon(icon, color: AppColors.primaryColor, size: 22),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodySemibold.copyWith(
                  color: AppColors.darkColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        customEditWidget ??
            Focus(
              onFocusChange: (hasFocus) {
                if (!hasFocus) {
                  // Handle focus loss with potential autosave
                  controller.handleFieldFocusLoss(context, field);
                }
              },
              child: buildTextField(
                context: context,
                controller: textController,
                hint: hint,
                error: error,
                keyboardType: keyboardType,
                suffixIcon: suffixIcon as IconButton?,
                onChanged: (value) => controller.trackFieldChange(field),
              ),
            ),
      ],
    );
  }
}
