import 'package:flutter/material.dart';
import 'package:xceleration/core/components/dropup_button.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import 'sample_spreadsheet_sheet.dart';

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
              color: Color(0xFFE2572B),
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
              foregroundColor: const Color(0xFFE2572B),
            ),
            child: const Text(
              'View Sample Spreadsheet',
              style: AppTypography.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: DropupButton<Map<String, dynamic>>(
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
                backgroundColor: const Color(0xFFE2572B),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: [
                PopupMenuItem<Map<String, dynamic>>(
                  value: const {'useGoogleDrive': true},
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Select Google Sheet',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      Icon(Icons.arrow_forward_ios,
                          color: Color(0xFFE2572B), size: 20),
                    ],
                  ),
                ),
                PopupMenuItem<Map<String, dynamic>>(
                  value: const {'useGoogleDrive': false},
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Select Local File',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      Icon(Icons.arrow_forward_ios,
                          color: Color(0xFFE2572B), size: 20),
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
