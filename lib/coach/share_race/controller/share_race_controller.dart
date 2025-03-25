import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:convert';

import '../../../../../utils/sheet_utils.dart';
import '../../../../../utils/share_utils.dart';
import '../../../../../core/components/dialog_utils.dart';
import '../screen/share_race_screen.dart';
import '../../results_screen/model/results_record.dart';
import '../../results_screen/model/team_record.dart';

/// Controller class responsible for all sharing logic in the app
class ShareRaceController {
  
  ShareRaceController();

  /// Show the share race bottom sheet
  static Future<dynamic> showShareRaceSheet({
    required BuildContext context,
    required List<List<TeamRecord>> headToHeadTeamResults,
    required List<TeamRecord> overallTeamResults,
    required List<ResultsRecord> individualResults,
  }) {
    return sheet(
      context: context,
      title: 'Share Race',
      body: ShareSheetScreen(
        headToHeadTeamResults: headToHeadTeamResults,
        overallTeamResults: overallTeamResults,
        individualResults: individualResults,
        controller: ShareRaceController(),
      ),
    );
  }

  /// Export the results to Google Sheets
  Future<String?> exportToGoogleSheets(
    BuildContext context,
    List<List<dynamic>> sheetsData,
  ) async {
    return await ShareUtils.exportToGoogleSheets(context, sheetsData);
  }
  
  /// Save results locally to a file
  Future<void> saveLocally(
    BuildContext context, 
    ResultFormat format,
    String formattedText,
    Future<pw.Document> Function() generatePdf
  ) async {
    try {
      final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return;

      final String extension = format == ResultFormat.pdf ? 'pdf' : 'txt';
      final file = File(path.join(selectedDirectory, 'race_results.$extension'));

      if (format == ResultFormat.pdf) {
        final pdfData = await generatePdf();
        await file.writeAsBytes(await pdfData.save());
      } else {
        await file.writeAsString(formattedText);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        DialogUtils.showErrorDialog(context, message: 'Failed to save file: $e');
      }
    }
  }

  /// Copy the results to clipboard
  Future<void> copyToClipboard(
    BuildContext context, 
    ResultFormat format,
    String formattedText,
    List<List<dynamic>> Function() getSheetsData,
  ) async {
    try {
      switch (format) {
        case ResultFormat.googleSheet:
          final sheetsData = getSheetsData();
          final sheetUrl = await exportToGoogleSheets(context, sheetsData);
          if (sheetUrl != null) {
            await Clipboard.setData(ClipboardData(text: sheetUrl));
          }
          break;
        
        case ResultFormat.pdf:
          DialogUtils.showErrorDialog(
            context,
            message: 'PDF format cannot be copied to clipboard. Please use Save or Email options instead.'
          );
          return;
        
        case ResultFormat.plainText:
          await Clipboard.setData(ClipboardData(text: formattedText));
          break;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        DialogUtils.showErrorDialog(context, message: 'Failed to copy to clipboard: $e');
      }
    }
  }

  /// Share results via email
  Future<void> sendEmail(
    BuildContext context, 
    ResultFormat format,
    String formattedText,
    List<List<dynamic>> Function() getSheetsData,
    Future<pw.Document> Function() generatePdf,
  ) async {
    try {
      switch (format) {
        case ResultFormat.googleSheet:
          final sheetsData = getSheetsData();
          final sheetUrl = await exportToGoogleSheets(context, sheetsData);
          if (sheetUrl != null) {
            await _launchEmail(
              context: context,
              subject: 'Race Results',
              body: 'Race results are available in the following Google Sheet:\n\n$sheetUrl',
            );
          }
          break;

        case ResultFormat.pdf:
          final pdfData = await generatePdf();
          final bytes = await pdfData.save();
          final base64Pdf = base64Encode(bytes);
          
          await _launchEmail(
            context: context,
            subject: 'Race Results',
            body: 'Please find attached the race results PDF.',
            attachment: 'data:application/pdf;base64,$base64Pdf',
          );
          break;

        case ResultFormat.plainText:
          await _launchEmail(
            context: context,
            subject: 'Race Results',
            body: formattedText,
          );
          break;
      }
    } catch (e) {
      if (context.mounted) {
        DialogUtils.showErrorDialog(context, message: 'Failed to send email: $e');
      }
    }
  }

  /// Share results via SMS
  Future<void> sendSms(
    BuildContext context, 
    ResultFormat format,
    String formattedText,
    List<List<dynamic>> Function() getSheetsData,
    Future<pw.Document> Function() generatePdf,
  ) async {
    try {
      String messageBody;
      if (format == ResultFormat.googleSheet) {
        final sheetsData = getSheetsData();
        final sheetUrl = await exportToGoogleSheets(context, sheetsData);
        messageBody = sheetUrl ?? 'Race results not available';
      } else if (format == ResultFormat.pdf) {
        final pdfData = await generatePdf();
        final bytes = await pdfData.save();
        
        final Uri smsLaunchUri = Uri.parse('sms:?&body=Please find the race results attached.');
        if (await canLaunchUrl(smsLaunchUri)) {
          await Share.shareXFiles(
            [
              XFile.fromData(
                bytes,
                name: 'race_results.pdf',
                mimeType: 'application/pdf',
              )
            ],
          );
        } else if (context.mounted) {
          DialogUtils.showErrorDialog(context, message: 'Could not share the PDF');
        }
        return;
      } else {
        messageBody = formattedText;
      }

      final Uri smsLaunchUri = Uri.parse('sms:&body=${Uri.encodeComponent(messageBody)}');

      if (await canLaunchUrl(smsLaunchUri)) {
        await launchUrl(smsLaunchUri);
      } else if (context.mounted) {
        DialogUtils.showErrorDialog(context, message: 'Could not launch SMS app');
      }
    } catch (e) {
      if (context.mounted) {
        DialogUtils.showErrorDialog(context, message: 'Failed to send SMS: $e');
      }
    }
  }

  // Helper method to launch email
  Future<void> _launchEmail({
    required BuildContext context,
    required String subject,
    required String body,
    String? attachment,
  }) async {
    final Map<String, String> params = {
      'subject': subject,
      'body': body,
    };
    if (attachment != null) {
      params['attachment'] = attachment;
    }

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      query: _encodeQueryParameters(params),
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else if (context.mounted) {
      DialogUtils.showErrorDialog(context, message: 'Could not launch email client');
    }
  }

  // Helper method to encode query parameters
  String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}
