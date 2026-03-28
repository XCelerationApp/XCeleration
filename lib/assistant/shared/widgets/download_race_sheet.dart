import 'package:flutter/material.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../services/assistant_export_service.dart';

/// Bottom sheet that lets the user choose between CSV and PDF download formats.
///
/// Closes itself with a [DownloadFormat] value when the user taps an option.
class DownloadRaceSheet extends StatelessWidget {
  const DownloadRaceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FormatTile(
          icon: Icons.table_chart_outlined,
          title: 'CSV',
          subtitle: 'Spreadsheet format — open in Excel or Google Sheets',
          onTap: () => Navigator.of(context).pop(DownloadFormat.csv),
        ),
        const SizedBox(height: AppSpacing.md),
        _FormatTile(
          icon: Icons.picture_as_pdf_outlined,
          title: 'PDF',
          subtitle: 'Print-friendly document',
          onTap: () => Navigator.of(context).pop(DownloadFormat.pdf),
        ),
      ],
    );
  }
}

class _FormatTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FormatTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_FormatTile> createState() => _FormatTileState();
}

class _FormatTileState extends State<_FormatTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.spring,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(color: AppColors.lightColor),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 28, color: AppColors.primaryColor),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: AppTypography.titleSemibold),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.subtitle,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.mediumColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.mediumColor,
            ),
          ],
        ),
      ),
    );
  }
}
