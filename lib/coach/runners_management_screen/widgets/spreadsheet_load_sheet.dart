import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import 'sample_spreadsheet_sheet.dart';

/// The action the user chose in the import sheet.
enum SpreadsheetImportAction { googleDrive, local, recent }

/// Where to import a spreadsheet from: Google Drive, a file on the phone,
/// or one used before. Each is its own button rather than hidden in a menu.
class SpreadsheetLoadSheet extends StatelessWidget {
  const SpreadsheetLoadSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Use a Google Sheet, Excel (.xlsx) or CSV file with a column for '
          'each runner\'s bib, name and grade (9 to 12). Add a Team column '
          'to import several teams at once.',
          style: AppTypography.bodyRegular.copyWith(color: AppColors.mediumColor),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => sheet(
              context: context,
              title: 'Sample Spreadsheet',
              body: const SampleSpreadsheetSheet(),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryColor,
              padding: EdgeInsets.zero,
            ),
            child: Text('See a sample spreadsheet',
                style: AppTypography.bodySemibold),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _SourceButton(
          icon: Icons.add_to_drive_outlined,
          label: 'Google Drive',
          detail: 'Pick a Google Sheet or file from your Drive',
          primary: true,
          onTap: () =>
              Navigator.pop(context, SpreadsheetImportAction.googleDrive),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SourceButton(
          icon: Icons.folder_open_outlined,
          label: 'Files on this phone',
          detail: 'A CSV or Excel file saved on the phone or in iCloud',
          onTap: () => Navigator.pop(context, SpreadsheetImportAction.local),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SourceButton(
          icon: Icons.history,
          label: 'Used before',
          detail: 'Import again from a spreadsheet you picked earlier',
          onTap: () => Navigator.pop(context, SpreadsheetImportAction.recent),
        ),
      ],
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : AppColors.darkColor;
    return Material(
      color: primary ? AppColors.primaryColor : AppColors.surfaceColor,
      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(icon, color: primary ? Colors.white : AppColors.primaryColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppTypography.bodySemibold.copyWith(color: fg)),
                    Text(detail,
                        style: AppTypography.smallBodyRegular.copyWith(
                            color: fg.withValues(alpha: 0.8))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: fg.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}
