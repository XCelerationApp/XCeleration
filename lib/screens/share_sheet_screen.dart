import 'package:flutter/material.dart';
import 'package:xcelerate/utils/sheet_utils.dart';
import '../utils/share_utils.dart';
import '../utils/dialog_utils.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

enum ResultFormat {
  plainText,
  googleSheet,
  pdf
}

class ShareSheetScreen extends StatefulWidget {
  final List<Map<String, dynamic>> teamResults;
  final List<Map<String, dynamic>> individualResults;

  const ShareSheetScreen({
    Key? key,
    required this.teamResults,
    required this.individualResults,
  }) : super(key: key);

  @override
  State<ShareSheetScreen> createState() => _ShareSheetScreenState();
}

class _ShareSheetScreenState extends State<ShareSheetScreen> {
  ResultFormat _selectedFormat = ResultFormat.plainText;

  String _getFormattedText() {
    final StringBuffer buffer = StringBuffer();
    
    // Team Results
    buffer.writeln('Team Results');
    buffer.writeln('Rank\tSchool\tScore\tSplit Time\tAverage Time');
    for (var team in widget.teamResults) {
      buffer.writeln('${team['place']}\t${team['school']}\t${team['score']}\t${team['split']}\t${team['averageTime']}');
    }
    
    // Individual Results
    buffer.writeln('\nIndividual Results');
    buffer.writeln('Place\tName\tSchool\tTime');
    for (var runner in widget.individualResults) {
      buffer.writeln('${runner['place']}\t${runner['name']}\t${runner['school']}\t${runner['finish_time']}');
    }
    
    return buffer.toString();
  }

  Future<void> _saveLocally(BuildContext context, ResultFormat format) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return;

      final file = File(path.join(
        selectedDirectory,
        'race_results.${format == ResultFormat.pdf ? 'pdf' : 'txt'}'
      ));

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

  Future<void> _copyToClipboard(BuildContext context, ResultFormat format) async {
    try {
      if (format == ResultFormat.googleSheet) {
        final sheetsData = _getSheetsData();
        final sheetUrl = await ShareUtils.exportToGoogleSheets(context, sheetsData);
        if (sheetUrl != null) {
          await Clipboard.setData(ClipboardData(text: sheetUrl));
        }
      } else if (format == ResultFormat.pdf) {
        final pdfData = await _generatePdf();
        // Since we can't copy PDF data directly to clipboard, we'll show a dialog
        DialogUtils.showErrorDialog(
          context,
          message: 'PDF format cannot be copied to clipboard. Please use Save or Email options instead.'
        );
        return;
      } else {
        await Clipboard.setData(ClipboardData(text: _getFormattedText()));
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

  List<List<dynamic>> _getSheetsData() {
    final List<List<dynamic>> sheetsData = [];
    
    // Add headers
    sheetsData.add(['Team Results']);
    sheetsData.add(['Rank', 'School', 'Score', 'Split Time', 'Average Time']);
    
    // Add team data
    for (var team in widget.teamResults) {
      sheetsData.add([
        team['place'],
        team['school'],
        team['score'],
        team['split'],
        team['averageTime'],
      ]);
    }
    
    // Add spacing and individual results header
    sheetsData.add([]);
    sheetsData.add(['Individual Results']);
    sheetsData.add(['Place', 'Name', 'School', 'Time']);
    
    // Add individual data
    for (var runner in widget.individualResults) {
      sheetsData.add([
        runner['place'],
        runner['name'],
        runner['school'],
        runner['finish_time'],
      ]);
    }

    return sheetsData;
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Race Results', style: pw.TextStyle(fontSize: 24)),
          ),
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

  Future<void> _sendEmail(BuildContext context, ResultFormat format) async {
    if (format == ResultFormat.googleSheet) {
      final sheetsData = _getSheetsData();
      final sheetUrl = await ShareUtils.exportToGoogleSheets(context, sheetsData);
      if (sheetUrl != null) {
        final Uri emailLaunchUri = Uri(
          scheme: 'mailto',
          query: encodeQueryParameters({
            'subject': 'Race Results',
            'body': 'Race results are available in the following Google Sheet:\n\n$sheetUrl',
          }),
        );
        if (await canLaunchUrl(emailLaunchUri)) {
          await launchUrl(emailLaunchUri);
        }
      }
    } else if (format == ResultFormat.pdf) {
      // For PDF, we'll save it first then attach it to the email
      try {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/race_results.pdf');
        final pdfData = await _generatePdf();
        await file.writeAsBytes(await pdfData.save());

        final Uri emailLaunchUri = Uri(
          scheme: 'mailto',
          query: encodeQueryParameters({
            'subject': 'Race Results',
            'body': 'Please find attached the race results PDF.',
            'attachment': file.path,
          }),
        );
        if (await canLaunchUrl(emailLaunchUri)) {
          await launchUrl(emailLaunchUri);
        }
      } catch (e) {
        if (mounted) {
          DialogUtils.showErrorDialog(
            context,
            message: 'Failed to generate PDF: $e'
          );
        }
      }
    } else {
      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        query: encodeQueryParameters({
          'subject': 'Race Results',
          'body': _getFormattedText(),
        }),
      );
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      }
    }

    if (mounted && !await canLaunchUrl(Uri(scheme: 'mailto'))) {
      DialogUtils.showErrorDialog(
        context,
        message: 'Could not launch email client'
      );
    }
  }

  String encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          createSheetHandle(height: 10, width: 60),
          const SizedBox(height: 8),
          const Text(
            'Select Format',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<ResultFormat>(
            segments: const [
              ButtonSegment<ResultFormat>(
                value: ResultFormat.plainText,
                label: Text('Plain Text'),
              ),
              ButtonSegment<ResultFormat>(
                value: ResultFormat.googleSheet,
                label: Text('Google Sheet'),
              ),
              ButtonSegment<ResultFormat>(
                value: ResultFormat.pdf,
                label: Text('PDF'),
              ),
            ],
            selected: {_selectedFormat},
            onSelectionChanged: (Set<ResultFormat> newSelection) {
              setState(() {
                _selectedFormat = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _selectedFormat == ResultFormat.googleSheet
                ? () => ShareUtils.exportToGoogleSheets(context, _getSheetsData())
                : () => _saveLocally(context, _selectedFormat),
            icon: Icon(_selectedFormat == ResultFormat.googleSheet
                ? Icons.cloud_upload
                : Icons.save),
            label: Text(_selectedFormat == ResultFormat.googleSheet
                ? 'Export to Google Sheets'
                : 'Save Locally'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _copyToClipboard(context, _selectedFormat),
            icon: const Icon(Icons.copy),
            label: Text(_selectedFormat == ResultFormat.googleSheet
                ? 'Copy Sheet Link'
                : 'Copy to Clipboard'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _sendEmail(context, _selectedFormat),
            icon: const Icon(Icons.email),
            label: const Text('Send via Email'),
          ),
        ],
      ),
    );
  }
}
