import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
// import '../../../../core/theme/typography.dart';
import '../../../../utils/enums.dart';

class FormatSelectionWidget extends StatelessWidget {
  final ResultFormat? selectedFormat;
  final void Function(ResultFormat) onFormatSelected;

  const FormatSelectionWidget({
    super.key,
    required this.selectedFormat,
    required this.onFormatSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   'Choose a format',
          //   style: AppTypography.titleMedium.copyWith(
          //     fontWeight: FontWeight.w600,
          //   ),
          // ),
          // const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _buildFormatOption(
                    format: ResultFormat.plainText,
                    label: 'Plain Text',
                    icon: Icons.text_snippet,
                    description: 'Copy as plain text',
                  ),
                  _buildFormatOption(
                    format: ResultFormat.googleSheet,
                    label: 'Google Sheet',
                    icon: Icons.cloud_upload,
                    description: 'Export to Google Sheets',
                  ),
                  _buildFormatOption(
                    format: ResultFormat.pdf,
                    label: 'PDF',
                    icon: Icons.picture_as_pdf,
                    description: 'Export as PDF',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatOption({
    required ResultFormat format,
    required String label,
    required IconData icon,
    required String description,
  }) {
    final isSelected = format == selectedFormat;
    return Expanded(
      child: InkWell(
        onTap: () => onFormatSelected(format),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryColor.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primaryColor.withOpacity(0.5) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected ? AppColors.primaryColor : Colors.black54,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppColors.primaryColor : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? AppColors.primaryColor.withOpacity(0.8) : Colors.black54,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
