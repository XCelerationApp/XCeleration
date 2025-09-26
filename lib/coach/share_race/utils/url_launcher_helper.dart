import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/components/dialog_utils.dart';

/// Helper class to handle URL launching operations
class UrlLauncherHelper {
  /// Launch a Google Sheet URL, attempting to open in the Sheets app first
  static Future<void> launchSheetUrl(BuildContext context, Uri sheetUri) async {
    try {
      // Try to launch with Google Sheets app scheme
      final sheetsAppUri = Uri.parse(
          'googlesheetsapp://spreadsheets.google.com/d/${sheetUri.toString()}');
      final canLaunchSheetsApp = await canLaunchUrl(sheetsAppUri);

      if (canLaunchSheetsApp) {
        Logger.d('Opening in Google Sheets app');
        await launchUrl(sheetsAppUri);
      } else {
        Logger.d('Opening in browser');
        await launchUrl(sheetUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      Logger.e('Error launching URL: $e');
      if (context.mounted) {
        DialogUtils.showErrorDialog(context,
            message: 'Unable to open Google Sheet');
      }
    }
  }
}
