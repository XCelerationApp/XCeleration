import 'package:flutter/material.dart';
import 'package:xceleration/core/components/dropup_button.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import 'sample_spreadsheet_sheet.dart';

/// The action the user chose in the import sheet.
enum SpreadsheetImportAction { googleDrive, local, recent }

class SpreadsheetLoadSheet extends StatelessWidget {
  const SpreadsheetLoadSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.insert_drive_file_outlined,
              color: AppColors.primaryColor,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Import Runners from Spreadsheet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Import your runners from a CSV or Excel spreadsheet. Recommended header: "Athlete #, First, Last, Year, M/F".',
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => sheet(
              context: context,
              title: 'Sample Spreadsheet',
              body: const SampleSpreadsheetSheet(),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryColor,
            ),
            child: const Text(
              'View Sample Spreadsheet',
              style: AppTypography.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: DropupButton<SpreadsheetImportAction>(
              onSelected: (result) {
                if (result != null) {
                  Navigator.pop(context, result);
                }
              },
              verticalOffset: 0,
              elevation: 8,
              menuShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              menuColor: Colors.white,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: [
                PopupMenuItem<SpreadsheetImportAction>(
                  value: SpreadsheetImportAction.recent,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Previously Selected Spreadsheets',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      Icon(Icons.history,
                          color: AppColors.primaryColor, size: 20),
                    ],
                  ),
                ),
                PopupMenuItem<SpreadsheetImportAction>(
                  value: SpreadsheetImportAction.googleDrive,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Select from Google Drive',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      Icon(Icons.arrow_forward_ios,
                          color: AppColors.primaryColor, size: 20),
                    ],
                  ),
                ),
                PopupMenuItem<SpreadsheetImportAction>(
                  value: SpreadsheetImportAction.local,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Select from Local Files',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      Icon(Icons.arrow_forward_ios,
                          color: AppColors.primaryColor, size: 20),
                    ],
                  ),
                ),
              ],
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.file_upload, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Import Spreadsheet', style: AppTypography.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
