import 'dart:async';
import '../../../utils/enums.dart';
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
import '../../race_results/model/results_record.dart';
import '../../race_results/model/team_record.dart';

/// Controller class responsible for all sharing logic in the app
class ShareRaceController extends ChangeNotifier {
  late final List<List<TeamRecord>> _headToHeadTeamResults;
  late final List<TeamRecord> _overallTeamResults;
  late final List<ResultsRecord> _individualResults;

  late String _formattedResultsText;
  late List<List<dynamic>> _formattedSheetsData;
  late pw.Document _formattedPdf;
  
  
  
  ShareRaceController({
    required headToHeadTeamResults,
    required overallTeamResults,
    required individualResults,
  }) {
    _headToHeadTeamResults = headToHeadTeamResults;
    _overallTeamResults = overallTeamResults;
    _individualResults = individualResults;
    _formattedResultsText = _getFormattedText();
    _formattedSheetsData = _getSheetsData();
    _formattedPdf = _getPdfDocument();
  }

  ResultFormat _selectedFormat = ResultFormat.plainText;
  
  ResultFormat get selectedFormat => _selectedFormat;
  
  set selectedFormat(ResultFormat format) {
    _selectedFormat = format;
    notifyListeners();
  }

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
        controller: ShareRaceController(
          headToHeadTeamResults: headToHeadTeamResults,
          overallTeamResults: overallTeamResults,
          individualResults: individualResults,
        ),
      ),
    );
  }

  // Text Formatting Methods
  String _getFormattedText() {
    final StringBuffer buffer = StringBuffer();
    
    // Team Results Section
    buffer.writeln('Team Results');
    buffer.writeln('Rank\tSchool\tScore\tSplit Time\tAverage Time');
    for (final team in _overallTeamResults) {
      buffer.writeln(
        '${team.place}\t${team.school}\t${team.score}\t'
        '${team.split}\t${team.avgTime}'
      );
    }
    
    // Head-to-Head Team Results Section
    buffer.writeln('Head-to-Head Team Results');
    buffer.writeln('Rank\tSchool\tScore\tSplit Time\tAverage Time');
    for (final matchup in _headToHeadTeamResults) {
      final team1 = matchup[0];
      final team2 = matchup[1];
      buffer.writeln(
        '${team1.place}\t${team1.school}\t${team1.score}\t'
        '${team1.split}\t${team1.avgTime}'
      );
      buffer.writeln(
        '${team2.place}\t${team2.school}\t${team2.score}\t'
        '${team2.split}\t${team2.avgTime}'
      );
    }
        // Individual Results Section
    buffer.writeln('\nIndividual Results');
    buffer.writeln('Place\tName\tSchool\tTime');
    for (final runner in _individualResults) {
      buffer.writeln(
        '${runner.place}\t${runner.name}\t${runner.school}\t'
        '${runner.finishTime}'
      );
    }
    
    return buffer.toString();
  }

  // Data Formatting Methods
  List<List<dynamic>> _getSheetsData() {
    final List<List<dynamic>> sheetsData = [
      // Team Results Section
      ['Team Results'],
      ['Rank', 'School', 'Score', 'Split Time', 'Average Time'],
      ..._overallTeamResults.map((team) => [
        team.place,
        team.school,
        team.score,
        team.split,
        team.avgTime,
      ]),
      
      // Spacing
      [],
      
      // Individual Results Section
      ['Individual Results'],
      ['Place', 'Name', 'School', 'Time'],
      ..._individualResults.map((runner) => [
        runner.place,
        runner.name,
        runner.school,
        runner.finishTime,
      ]),
    ];

    return sheetsData;
  }

  pw.Document _getPdfDocument() {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          // Title
          pw.Header(
            level: 0,
            child: pw.Text('Race Results', style: pw.TextStyle(fontSize: 24)),
          ),
          
          // Team Results Section
          pw.Header(level: 1, child: pw.Text('Team Results')),
          pw.TableHelper.fromTextArray(
            headers: ['Rank', 'School', 'Score', 'Split Time', 'Average Time'],
            data: _overallTeamResults.map((team) => [
              team.place.toString(),
              team.school.toString(),
              team.score.toString(),
              team.split.toString(),
              team.avgTime.toString(),
            ]).toList(),
          ),
          
          pw.SizedBox(height: 20),
          
          // Individual Results Section
          pw.Header(level: 1, child: pw.Text('Individual Results')),
          pw.TableHelper.fromTextArray(
            headers: ['Place', 'Name', 'School', 'Time'],
            data: _individualResults.map((runner) => [
              runner.place.toString(),
              runner.name.toString(),
              runner.school.toString(),
              runner.finishTime.toString(),
            ]).toList(),
          ),
        ],
      ),
    );

    return pdf;
  }

  /// Export the results to Google Sheets
  Future<String?> exportToGoogleSheets(
    BuildContext context,
  ) async {
    return await ShareUtils.exportToGoogleSheets(context, _formattedSheetsData);
  }
  
  /// Save results locally to a file
  Future<void> saveLocally(
    BuildContext context, 
    ResultFormat format,
  ) async {
    try {
      final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return;

      final String extension = format == ResultFormat.pdf ? 'pdf' : 'txt';
      final file = File(path.join(selectedDirectory, 'race_results.$extension'));

      if (format == ResultFormat.pdf) {
        await file.writeAsBytes(await _formattedPdf.save());
      } else {
        await file.writeAsString(_formattedResultsText);
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
  ) async {
    try {
      switch (format) {
        case ResultFormat.googleSheet:
          final sheetUrl = await exportToGoogleSheets(context);
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
          await Clipboard.setData(ClipboardData(text: _formattedResultsText));
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
  ) async {
    try {
      switch (format) {
        case ResultFormat.googleSheet:
          final sheetUrl = await exportToGoogleSheets(context);
          if (sheetUrl != null) {
            await _launchEmail(
              context: context,
              subject: 'Race Results',
              body: 'Race results are available in the following Google Sheet:\n\n$sheetUrl',
            );
          }
          break;

        case ResultFormat.pdf:
          final pdfData = _formattedPdf;
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
            body: _formattedResultsText,
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
  ) async {
    try {
      String messageBody;
      if (format == ResultFormat.googleSheet) {
        final sheetUrl = await exportToGoogleSheets(context);
        messageBody = sheetUrl ?? 'Race results not available';
      } else if (format == ResultFormat.pdf) {
        final pdfData = _formattedPdf;
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
        messageBody = _formattedResultsText;
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
