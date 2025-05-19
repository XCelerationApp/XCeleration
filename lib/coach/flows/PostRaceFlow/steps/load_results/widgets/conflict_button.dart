import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/components/button_components.dart';
import 'package:xceleration/core/utils/color_utils.dart';

class ConflictButton extends StatelessWidget {
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onPressed;

  const ConflictButton({
    super.key,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.bodySemibold
                    .copyWith(color: Colors.amber.shade700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: AppTypography.bodyRegular
                .copyWith(color: ColorUtils.withOpacity(AppColors.darkColor, 0.8)),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            text: buttonText,
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            onPressed: onPressed,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }
}
