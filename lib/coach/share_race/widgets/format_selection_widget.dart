import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../utils/enums.dart';

class FormatSelectionWidget extends StatelessWidget {
  final void Function(ResultFormat) onShareSelected;
  final void Function(ResultFormat) onCopySelected;

  const FormatSelectionWidget({
    super.key,
    required this.onShareSelected,
    required this.onCopySelected,
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
                  color: Colors.black.withOpacity(0.05),
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
                    description: 'Share as plain text',
                  ),
                  const Divider(
                      height: 1, thickness: 0.5, color: Colors.black12),
                  _buildFormatOption(
                    format: ResultFormat.googleSheet,
                    label: 'Google Sheet',
                    icon: Icons.cloud_upload,
                    description: 'Export to Google Sheets',
                  ),
                  const Divider(
                      height: 1, thickness: 0.5, color: Colors.black12),
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
    // If it's plainText, clicking anywhere copies it
    if (format == ResultFormat.plainText) {
      return InkWell(
        onTap: () => onCopySelected(format),
        borderRadius: BorderRadius.circular(16),
        child: _buildFormatContainer(
          icon: icon,
          label: label,
          description: description,
          showCopyButton: false,
        ),
      );
    }
    
    // For Google Sheet, show Copy button
    if (format == ResultFormat.googleSheet) {
      return InkWell(
        onTap: () => onShareSelected(format),
        borderRadius: BorderRadius.circular(16),
        child: _buildFormatContainer(
          icon: icon,
          label: label,
          description: description,
          showCopyButton: true,
          onCopyPressed: () => onCopySelected(format),
        ),
      );
    }
    
    // For other formats (like PDF), standard behavior
    return InkWell(
      onTap: () => onShareSelected(format),
      borderRadius: BorderRadius.circular(16),
      child: _buildFormatContainer(
        icon: icon,
        label: label,
        description: description,
        showCopyButton: false,
      ),
    );
  }
  
  Widget _buildFormatContainer({
    required IconData icon,
    required String label,
    required String description,
    required bool showCopyButton,
    VoidCallback? onCopyPressed,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color: Colors.black54.withOpacity(0.8),
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
                    color: Colors.black87.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54.withOpacity(0.7),
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (showCopyButton) ...[  
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onCopyPressed,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.content_copy,
                    size: 20,
                    color: Colors.black54.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
