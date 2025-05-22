import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../utils/enums.dart';
import 'package:xceleration/core/utils/color_utils.dart';

class FormatSelectionWidget extends StatelessWidget {
  final void Function(ResultFormat) onShareSelected;

  const FormatSelectionWidget({
    super.key,
    required this.onShareSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.withOpacity(Colors.black, 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Column(
                children: [
                  _buildFormatOption(
                    format: ResultFormat.plainText,
                    label: 'Plain Text',
                    icon: Icons.text_snippet,
                    description: 'Copy Results as Plain Text',
                  ),
                  const Divider(
                      height: 1, thickness: 0.5, color: Colors.black12),
                  _buildFormatOption(
                    format: ResultFormat.googleSheet,
                    label: 'Google Sheet',
                    icon: Icons.cloud_upload,
                    description: 'Save/Share Results to Google Sheet',
                  ),
                  const Divider(
                      height: 1, thickness: 0.5, color: Colors.black12),
                  _buildFormatOption(
                    format: ResultFormat.pdf,
                    label: 'PDF',
                    icon: Icons.picture_as_pdf,
                    description: 'Save/Share Results as PDF',
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
    return InkWell(
      onTap: () => onShareSelected(format),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: ColorUtils.withOpacity(Colors.black54, 0.8),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.withOpacity(Colors.black87, 0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: ColorUtils.withOpacity(Colors.black54, 0.7),
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      )
    );
  }
}
