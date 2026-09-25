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
                label: 'Copy as Text',
                icon: Icons.content_copy_outlined,
                description: 'Paste into a message, email or post',
              ),
              const Divider(height: 1, thickness: 0.5, color: AppColors.borderColor),
              _buildFormatOption(
                format: ResultFormat.googleSheet,
                label: 'Google Sheets',
                icon: Icons.grid_on_outlined,
                description: 'Make a new sheet in your Google Drive',
              ),
              const Divider(height: 1, thickness: 0.5, color: AppColors.borderColor),
              _buildFormatOption(
                format: ResultFormat.pdf,
                label: 'PDF',
                icon: Icons.picture_as_pdf_outlined,
                description: 'Ready to print or send',
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
