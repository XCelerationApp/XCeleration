import 'package:flutter/material.dart';
import '../core/components/dialog_utils.dart';
import 'google_sheets_utils.dart';

class ShareUtils {
  static Future<Uri?> createGoogleSheet(
    BuildContext context,
    List<List<dynamic>> sheetsData,
    String title,
  ) async {
    try {
      // First check if we're already signed in
      if (!await GoogleSheetsUtils.testSignIn(context)) {
        if (!context.mounted) return null;
        DialogUtils.showErrorDialog(
          context,
          message:
              'Please sign in to your Google account to export to Google Sheets',
        );
        return null;
      }

      // Check if context is still mounted before showing dialog
      if (!context.mounted) return null;
      
      DialogUtils.showLoadingDialog(context, message: 'Creating Google Sheet...');
      
      // Try to create the spreadsheet
      // Check if context is still mounted before calling APIs
      if (!context.mounted) return null;
      
      final url = await GoogleSheetsUtils.createSpreadsheet(
        context,
        title: title,
        data: sheetsData,
      );
      
      // Check if context is still mounted after spreadsheet creation
      if (!context.mounted) return null;
      
      Navigator.of(context, rootNavigator: true).pop();
      if (url != null) {
        return Uri.parse(url);
      }
      if (!context.mounted) return null;
      DialogUtils.showErrorDialog(context,
          message: 'Failed to export to Google Sheets. Please try again.');
      return null;
    } catch (e) {
      DialogUtils.showErrorDialog(context,
          message: 'Error exporting to Google Sheets: $e');
      return null;
    }
  }
}
