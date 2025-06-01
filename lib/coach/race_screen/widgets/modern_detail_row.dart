import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/app_colors.dart';
import 'package:xceleration/core/utils/color_utils.dart';

class ModernDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isMultiLine;

  const ModernDetailRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.isMultiLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment:
            isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
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
                  value,
                  style: AppTypography.bodySemibold.copyWith(
                    color: AppColors.mediumColor,
                  ),
                  maxLines: isMultiLine ? null : 1,
                  overflow: isMultiLine ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
