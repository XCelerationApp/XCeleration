import 'package:flutter/material.dart';
import '../../../../core/theme/app_border_radius.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../core/utils/enums.dart';

class FormatSelectionWidget extends StatelessWidget {
  final void Function(ResultFormat) onShareSelected;

  const FormatSelectionWidget({
    super.key,
    required this.onShareSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundColor,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            boxShadow: AppShadows.low,
          ),
          child: Column(
            children: [
              _buildFormatOption(
                format: ResultFormat.plainText,
                label: 'Plain Text',
                icon: Icons.text_snippet,
                description: 'Copy Results as Plain Text',
              ),
              const Divider(height: 1, thickness: 0.5, color: AppColors.borderColor),
              _buildFormatOption(
                format: ResultFormat.googleSheet,
                label: 'Google Sheet',
                icon: Icons.cloud_upload,
                description: 'Save/Share Results to Google Sheet',
              ),
              const Divider(height: 1, thickness: 0.5, color: AppColors.borderColor),
              _buildFormatOption(
                format: ResultFormat.pdf,
                label: 'PDF',
                icon: Icons.picture_as_pdf,
                description: 'Save/Share Results as PDF',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormatOption({
    required ResultFormat format,
    required String label,
    required IconData icon,
    required String description,
  }) {
    return InkWell(
        onTap: () => onShareSelected(format),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: AppColors.mediumColor,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.bodySemibold
                          .copyWith(color: AppColors.darkColor),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description,
                      style: AppTypography.smallBodyRegular
                          .copyWith(color: AppColors.mediumColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }
}
