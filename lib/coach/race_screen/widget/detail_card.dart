import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/app_colors.dart';

class DetailCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final bool isMultiLine;

  const DetailCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    this.isMultiLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: AppTypography.bodySemibold.copyWith(
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: AppTypography.titleSemibold.copyWith(
              color: AppColors.darkColor,
              fontSize: isMultiLine ? 16 : 18,
            ),
            maxLines: isMultiLine ? null : 1,
            overflow: isMultiLine ? null : TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
