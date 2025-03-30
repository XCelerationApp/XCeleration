import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/components/dialog_utils.dart';
import 'google_sheets_utils.dart';

class ShareUtils {
  static Future<String?> exportToGoogleSheets(
    BuildContext context,
    List<List<dynamic>> sheetsData,
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

      // Try to create the spreadsheet
      final url = await GoogleSheetsUtils.createSpreadsheet(
        context,
        title: 'Race Results ${DateTime.now().toString()}'.replaceAll(' ', '_'),
        data: sheetsData,
      );

      if (url != null) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          if (!context.mounted) return null;
          DialogUtils.showSuccessDialog(context,
              message: 'Results exported to Google Sheets successfully');
          return url;
        }
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

  static Future<void> shareAsText(BuildContext context, String text) async {
    try {
      if (Theme.of(context).platform == TargetPlatform.macOS) {
        // For macOS, use clipboard and show a notification
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          DialogUtils.showSuccessDialog(context,
              message: 'Results copied to clipboard');
        }
      } else {
        await Share.share(text);
      }
    } catch (e) {
      if (!context.mounted) return;
      DialogUtils.showErrorDialog(context, message: 'Failed to share text: $e');
    }
  }
}
