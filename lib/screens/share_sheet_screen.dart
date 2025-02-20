// Flutter imports
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Third-party package imports
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
// import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// Local imports
import '../utils/sheet_utils.dart';
import '../utils/share_utils.dart';
import '../utils/dialog_utils.dart';
import '../utils/app_colors.dart';

// Dart imports
import 'dart:io';
import 'dart:convert';

/// Enum defining the available formats for exporting results
enum ResultFormat {
  plainText,
  googleSheet,
  pdf,
}

class ShareSheetScreen extends StatefulWidget {
  final List<Map<String, dynamic>> teamResults;
  final List<Map<String, dynamic>> individualResults;

  const ShareSheetScreen({
    super.key,
    required this.teamResults,
    required this.individualResults,
  });

  @override
  State<ShareSheetScreen> createState() => _ShareSheetScreenState();
}

class _ShareSheetScreenState extends State<ShareSheetScreen> {
  ResultFormat _selectedFormat = ResultFormat.plainText;

  // Text Formatting Methods
  String _getFormattedText() {
    final StringBuffer buffer = StringBuffer();
    
    // Team Results Section
    buffer.writeln('Team Results');
    buffer.writeln('Rank\tSchool\tScore\tSplit Time\tAverage Time');
    for (final team in widget.teamResults) {
      buffer.writeln(
        '${team['place']}\t${team['school']}\t${team['score']}\t'
        '${team['split']}\t${team['averageTime']}'
      );
    }
    
    // Individual Results Section
    buffer.writeln('\nIndividual Results');
    buffer.writeln('Place\tName\tSchool\tTime');
    for (final runner in widget.individualResults) {
      buffer.writeln(
        '${runner['place']}\t${runner['name']}\t${runner['school']}\t'
        '${runner['finish_time']}'
      );
    }
    
    return buffer.toString();
  }

  // File Operations
  Future<void> _saveLocally(BuildContext context, ResultFormat format) async {
    try {
      final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return;

      final String extension = format == ResultFormat.pdf ? 'pdf' : 'txt';
      final file = File(path.join(selectedDirectory, 'race_results.$extension'));

      if (format == ResultFormat.pdf) {
        final pdfData = await _generatePdf();
        await file.writeAsBytes(await pdfData.save());
      } else {
        await file.writeAsString(_getFormattedText());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showErrorDialog(context, message: 'Failed to save file: $e');
      }
    }
  }

  // Clipboard Operations
  Future<void> _copyToClipboard(BuildContext context, ResultFormat format) async {
    try {
      switch (format) {
        case ResultFormat.googleSheet:
          final sheetsData = _getSheetsData();
          final sheetUrl = await ShareUtils.exportToGoogleSheets(context, sheetsData);
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
          await Clipboard.setData(ClipboardData(text: _getFormattedText()));
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard')),
        );
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showErrorDialog(context, message: 'Failed to copy to clipboard: $e');
      }
    }
  }

  // Data Formatting Methods
  List<List<dynamic>> _getSheetsData() {
    final List<List<dynamic>> sheetsData = [
      // Team Results Section
      ['Team Results'],
      ['Rank', 'School', 'Score', 'Split Time', 'Average Time'],
      ...widget.teamResults.map((team) => [
        team['place'],
        team['school'],
        team['score'],
        team['split'],
        team['averageTime'],
      ]),
      
      // Spacing
      [],
      
      // Individual Results Section
      ['Individual Results'],
      ['Place', 'Name', 'School', 'Time'],
      ...widget.individualResults.map((runner) => [
        runner['place'],
        runner['name'],
        runner['school'],
        runner['finish_time'],
      ]),
    ];

    return sheetsData;
  }

  Future<pw.Document> _generatePdf() async {
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
          pw.Table.fromTextArray(
            headers: ['Rank', 'School', 'Score', 'Split Time', 'Average Time'],
            data: widget.teamResults.map((team) => [
              team['place'].toString(),
              team['school'].toString(),
              team['score'].toString(),
              team['split'].toString(),
              team['averageTime'].toString(),
            ]).toList(),
          ),
          
          pw.SizedBox(height: 20),
          
          // Individual Results Section
          pw.Header(level: 1, child: pw.Text('Individual Results')),
          pw.Table.fromTextArray(
            headers: ['Place', 'Name', 'School', 'Time'],
            data: widget.individualResults.map((runner) => [
              runner['place'].toString(),
              runner['name'].toString(),
              runner['school'].toString(),
              runner['finish_time'].toString(),
            ]).toList(),
          ),
        ],
      ),
    );

    return pdf;
  }

  // Sharing Methods
  Future<void> _sendEmail(BuildContext context, ResultFormat format) async {
    try {
      switch (format) {
        case ResultFormat.googleSheet:
          final sheetsData = _getSheetsData();
          final sheetUrl = await ShareUtils.exportToGoogleSheets(context, sheetsData);
          if (sheetUrl != null) {
            await _launchEmail(
              subject: 'Race Results',
              body: 'Race results are available in the following Google Sheet:\n\n$sheetUrl',
            );
          }
          break;

        case ResultFormat.pdf:
          final pdfData = await _generatePdf();
          final bytes = await pdfData.save();
          final base64Pdf = base64Encode(bytes);
          
          await _launchEmail(
            subject: 'Race Results',
            body: 'Please find attached the race results PDF.',
            attachment: 'data:application/pdf;base64,$base64Pdf',
          );
          break;

        case ResultFormat.plainText:
          await _launchEmail(
            subject: 'Race Results',
            body: _getFormattedText(),
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showErrorDialog(context, message: 'Failed to send email: $e');
      }
    }
  }

  Future<void> _sendSms(BuildContext context, ResultFormat format) async {
    try {
      String messageBody;
      if (format == ResultFormat.googleSheet) {
        final sheetsData = _getSheetsData();
        final sheetUrl = await ShareUtils.exportToGoogleSheets(context, sheetsData);
        messageBody = sheetUrl ?? 'Race results not available';
      } else if (format == ResultFormat.pdf) {
        final pdfData = await _generatePdf();
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
        } else if (mounted) {
          DialogUtils.showErrorDialog(context, message: 'Could not share the PDF');
        }
        return;
      } else {
        messageBody = _getFormattedText();
      }

      final Uri smsLaunchUri = Uri.parse('sms:&body=${Uri.encodeComponent(messageBody)}');

      if (await canLaunchUrl(smsLaunchUri)) {
        await launchUrl(smsLaunchUri);
      } else if (mounted) {
        DialogUtils.showErrorDialog(context, message: 'Could not launch SMS app');
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showErrorDialog(context, message: 'Failed to send SMS: $e');
      }
    }
  }

  // Helper Methods
  Future<void> _launchEmail({
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
    } else if (mounted) {
      DialogUtils.showErrorDialog(context, message: 'Could not launch email client');
    }
  }

  String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: AppColors.unselectedRoleTextColor,
              width: 1,
            ),
          ),
          child: SegmentedButton<ResultFormat>(
            selectedIcon: const Icon(
              Icons.check,
              color: AppColors.unselectedRoleColor,
            ),
            segments: const [
              ButtonSegment<ResultFormat>(
                value: ResultFormat.plainText,
                label: Center(
                  child: Text(
                    'Plain Text',
                    style: TextStyle(fontSize: 16, height: 1.2),
                  ),
                ),
              ),
              ButtonSegment<ResultFormat>(
                value: ResultFormat.googleSheet,
                label: Center(
                  child: Text(
                    'Google Sheet',
                    style: TextStyle(fontSize: 16, height: 1.2),
                  ),
                ),
              ),
              ButtonSegment<ResultFormat>(
                value: ResultFormat.pdf,
                label: Center(
                  child: Text(
                    'PDF',
                    style: TextStyle(fontSize: 16, height: 1.2),
                  ),
                ),
              ),
            ],
            selected: {_selectedFormat},
            onSelectionChanged: (Set<ResultFormat> newSelection) {
              setState(() => _selectedFormat = newSelection.first);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) => 
                states.contains(WidgetState.selected) 
                  ? AppColors.primaryColor 
                  : AppColors.backgroundColor
              ),
              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) =>
                states.contains(WidgetState.selected)
                  ? AppColors.unselectedRoleColor
                  : AppColors.unselectedRoleTextColor
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        
        // Action Buttons
        _buildActionButton(
          icon: _selectedFormat == ResultFormat.googleSheet
              ? Icons.cloud_upload
              : Icons.save,
          label: _selectedFormat == ResultFormat.googleSheet
              ? 'Export to Google Sheets'
              : 'Save Locally',
          onPressed: () => _selectedFormat == ResultFormat.googleSheet
              ? ShareUtils.exportToGoogleSheets(context, _getSheetsData())
              : _saveLocally(context, _selectedFormat),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.copy,
          label: _selectedFormat == ResultFormat.googleSheet
              ? 'Copy Sheet Link'
              : 'Copy to Clipboard',
          onPressed: () => _selectedFormat == ResultFormat.pdf
              ? null
              : () => _copyToClipboard(context, _selectedFormat),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.email,
          label: 'Send via Email',
          onPressed: () => _sendEmail(context, _selectedFormat),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.sms,
          label: 'Send via SMS',
          onPressed: () => _sendSms(context, _selectedFormat),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
