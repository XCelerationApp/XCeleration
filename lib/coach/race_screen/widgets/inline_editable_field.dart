import 'package:flutter/material.dart';
import 'package:xceleration/core/components/textfield_utils.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/app_colors.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import '../controller/race_screen_controller.dart';

class InlineEditableField extends StatelessWidget {
  final RaceController controller;
  final String fieldName;
  final String label;
  final IconData icon;
  final TextEditingController textController;
  final String hint;
  final String? error;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final Widget? customEditWidget;
  final String Function()? getDisplayValue;

  const InlineEditableField({
    super.key,
    required this.controller,
    required this.fieldName,
    required this.label,
    required this.icon,
    required this.textController,
    required this.hint,
    this.error,
    this.keyboardType,
    this.suffixIcon,
    this.customEditWidget,
    this.getDisplayValue,
  });

  @override
  Widget build(BuildContext context) {
    final shouldShowAsEditable = controller.shouldShowAsEditable(fieldName);
    final displayValue = getDisplayValue?.call() ?? textController.text;
    final isEmpty = displayValue.isEmpty ||
        displayValue == 'Not set' ||
        displayValue == '0 ';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: shouldShowAsEditable
          ? _buildEditableMode(context)
          : _buildViewMode(context, displayValue, isEmpty),
    );
  }

  Widget _buildViewMode(
      BuildContext context, String displayValue, bool isEmpty) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ColorUtils.withOpacity(AppColors.primaryColor, 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryColor, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.bodySemibold.copyWith(
                  color: AppColors.darkColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isEmpty ? 'Not set' : displayValue,
                style: AppTypography.bodySemibold.copyWith(
                  color: isEmpty ? AppColors.lightColor : AppColors.mediumColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (controller.canEdit) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: () => controller.startEditingField(fieldName),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.edit,
                color: AppColors.primaryColor,
                size: 20,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditableMode(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ColorUtils.withOpacity(AppColors.primaryColor, 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryColor, size: 22),
            ),
            const SizedBox(width: 16),
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
        const SizedBox(height: 12),
        customEditWidget ??
            Focus(
              onFocusChange: (hasFocus) {
                if (!hasFocus) {
                  // Handle focus loss with potential autosave
                  controller.handleFieldFocusLoss(context, fieldName);
                }
              },
              child: buildTextField(
                context: context,
                controller: textController,
                hint: hint,
                error: error,
                keyboardType: keyboardType,
                suffixIcon: suffixIcon as IconButton?,
                setSheetState: (fn) =>
                    fn(), // No-op since we don't use sheet state
                onChanged: (value) => controller.trackFieldChange(fieldName),
              ),
            ),
      ],
    );
  }
}
