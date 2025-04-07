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
import '../../race_results/controller/race_results_controller.dart';
import '../../race_results/model/team_record.dart';

/// Controller class responsible for all sharing logic in the app
class ShareRaceController extends ChangeNotifier {
  late final RaceResultsController controller;

  late String _formattedResultsText;
  late List<List<dynamic>> _formattedSheetsData;
  late pw.Document _formattedPdf;

  ShareRaceController({
    required this.controller,
  }) {
    _formattedResultsText = _getFormattedText();
    _formattedSheetsData = _getSheetsData();
    _formattedPdf = _getPdfDocument();
  }

  ResultFormat? _selectedFormat;

  ResultFormat? get selectedFormat => _selectedFormat;

  set selectedFormat(ResultFormat? format) {
    _selectedFormat = format;
    notifyListeners();
  }

  /// Show the share race bottom sheet
  static Future<dynamic> showShareRaceSheet({
    required BuildContext context,
    required RaceResultsController controller,
  }) {
    return sheet(
      context: context,
      title: 'Share Race',
      body: ShareSheetScreen(
        controller: ShareRaceController(
          controller: controller,
        ),
      ),
    );
  }

  // Text Formatting Methods
  String _getFormattedText() {
    final StringBuffer buffer = StringBuffer();

    // Team Results Section
    buffer.writeln('Team Results');
    buffer.writeln('Place\tSchool\tScore\tSplit Time\tAverage Time');
    for (final team in controller.overallTeamResults) {
      buffer.writeln('${team.place}\t${team.school}\t${team.score != 0 ? team.score : 'N/A'}\t'
          '${team.split != Duration.zero ? team.split.toString() : 'N/A'}\t'
          '${team.avgTime != Duration.zero ? team.avgTime.toString() : 'N/A'}');
    }

    // Individual Results Section
    buffer.writeln('\nIndividual Results');
    buffer.writeln('Place\tName\tSchool\tTime');
    for (final runner in controller.individualResults) {
      buffer.writeln('${runner.place}\t${runner.name}\t${runner.school}\t'
          '${runner.finishTime}');
    }

    return buffer.toString();
  }

  // Data Formatting Methods
  List<List<dynamic>> _getSheetsData() {
    final List<List<dynamic>> sheetsData = [
      // Team Results Section
      ['Team Results'],
      ['Place', 'School', 'Score', 'Scorers', 'Split Time', 'Average Time'],
      ...controller.overallTeamResults.map((team) => [
            team.place,
            team.school,
            team.score != 0 ? team.score : 'N/A',
            team.scorers.isEmpty
                ? 'N/A'
                : team.scorers.map((scorer) => scorer.place.toString()).join(', '),
            team.split != Duration.zero ? team.split.toString() : 'N/A',
            team.avgTime != Duration.zero ? team.avgTime.toString() : 'N/A',
          ]),

      // Spacing
      [],

      // Head-to-Head Team Results Sections
      if (controller.headToHeadTeamResults != null) ...[
        ...controller.headToHeadTeamResults!.expand((matchup) {
          final team1 = matchup[0];
          final team2 = matchup[1];

          // Get the max number of runners to show
          final maxRunners = team1.runners.length > team2.runners.length
              ? team1.runners.length
              : team2.runners.length;

          // Create a header for this matchup
          final matchupHeader = ['${team1.school} vs ${team2.school}', '', ''];

          // Create column headers
          final columnHeaders = ['', team1.school, team2.school];

          // Create data rows for each runner
          List<List<dynamic>> runnerRows = [];
          for (int i = 0; i < maxRunners; i++) {
            // Runner from first team (if exists)
            String team1Place =
                i < team1.runners.length ? '#${team1.runners[i].place}' : '';
            String team1Name =
                i < team1.runners.length ? team1.runners[i].name : '';

            // Runner from second team (if exists)
            String team2Place =
                i < team2.runners.length ? '#${team2.runners[i].place}' : '';
            String team2Name =
                i < team2.runners.length ? team2.runners[i].name : '';

            runnerRows.add([
              '${i + 1}',
              team1Place.isNotEmpty ? '$team1Place $team1Name' : '',
              team2Place.isNotEmpty ? '$team2Place $team2Name' : ''
            ]);
          }

          // Summary row
          final summaryRow = ['Score',
            '${team1.score != 0 ? team1.score : 'N/A'}',
            '${team2.score != 0 ? team2.score : 'N/A'}'];

          return [
            matchupHeader,
            columnHeaders,
            ...runnerRows,
            summaryRow,
            [], // Add empty row as spacing between matchups
          ];
        })
      ],

      // Individual Results Section
      ['Individual Results'],
      ['Place', 'Name', 'School', 'Time'],
      ...controller.individualResults.map((runner) => [
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
            headers: [
              'Place',
              'School',
              'Score',
              'Scorers',
              'Split Time',
              'Average Time'
            ],
            data: controller.overallTeamResults
                .map((team) => [
                      team.place.toString(),
                      team.school.toString(),
                      team.score != 0 ? team.score.toString() : 'N/A',
                      team.scorers.isNotEmpty
                          ? team.scorers
                              .map((scorer) => scorer.place.toString())
                              .join(', ')
                          : 'N/A',
                      team.split != Duration.zero
                          ? team.split.toString()
                          : 'N/A',
                      team.avgTime != Duration.zero
                          ? team.avgTime.toString()
                          : 'N/A',
                    ])
                .toList(),
          ),

          pw.SizedBox(height: 20),

          // Head-to-Head Team Results Sections
          if (controller.headToHeadTeamResults != null) ...[
            pw.Header(level: 1, child: pw.Text('Head-to-Head Team Results')),
            pw.SizedBox(height: 10),

            // Generate each head-to-head matchup section
            for (final matchup in controller.headToHeadTeamResults!) ...[
              pw.Header(
                  level: 2,
                  child:
                      pw.Text('${matchup[0].school} vs ${matchup[1].school}')),

              // Table with the results
              pw.TableHelper.fromTextArray(
                headers: ['', matchup[0].school, matchup[1].school],
                data: _generateHeadToHeadRows(matchup[0], matchup[1]),
              ),

              pw.SizedBox(height: 20),
            ],
          ],

          pw.SizedBox(height: 20),

          // Individual Results Section
          pw.Header(level: 1, child: pw.Text('Individual Results')),
          pw.TableHelper.fromTextArray(
            headers: ['Place', 'Name', 'School', 'Time'],
            data: controller.individualResults
                .map((runner) => [
                      runner.place.toString(),
                      runner.name.toString(),
                      runner.school.toString(),
                      runner.finishTime.toString(),
                    ])
                .toList(),
          ),
        ],
      ),
    );

    return pdf;
  }

  List<List<String>> _generateHeadToHeadRows(
      TeamRecord team1, TeamRecord team2) {
    final List<List<String>> rows = [];
    final maxRunners = team1.runners.length > team2.runners.length
        ? team1.runners.length
        : team2.runners.length;

    for (int i = 0; i < maxRunners; i++) {
      // Runner from first team (if exists)
      String team1Place =
          i < team1.runners.length ? '#${team1.runners[i].place}' : '';
      String team1Name = i < team1.runners.length ? team1.runners[i].name : '';

      // Runner from second team (if exists)
      String team2Place =
          i < team2.runners.length ? '#${team2.runners[i].place}' : '';
      String team2Name = i < team2.runners.length ? team2.runners[i].name : '';

      rows.add([
        '${i + 1}',
        team1Place.isNotEmpty ? '$team1Place $team1Name' : '',
        team2Place.isNotEmpty ? '$team2Place $team2Name' : ''
      ]);
    }

    // Add summary row
    rows.add(['Score',
      '${team1.score != 0 ? team1.score : 'N/A'}',
      '${team2.score != 0 ? team2.score : 'N/A'}']);

    return rows;
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
      final String? selectedDirectory =
          await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return;

      final String extension = format == ResultFormat.pdf ? 'pdf' : 'txt';
      final file =
          File(path.join(selectedDirectory, 'race_results.$extension'));

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
        DialogUtils.showErrorDialog(context,
            message: 'Failed to save file: $e');
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
          DialogUtils.showErrorDialog(context,
              message:
                  'PDF format cannot be copied to clipboard. Please use Save or Email options instead.');
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
        DialogUtils.showErrorDialog(context,
            message: 'Failed to copy to clipboard: $e');
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
              body:
                  'Race results are available in the following Google Sheet:\n\n$sheetUrl',
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
        DialogUtils.showErrorDialog(context,
            message: 'Failed to send email: $e');
      }
    }
  }

  /// Share results via SMS
  Future<void> sendSms(
    BuildContext context,
    ResultFormat format,
  ) async {
    try {
      if (format == ResultFormat.googleSheet) {
        final sheetUrl = await exportToGoogleSheets(context);
        if (sheetUrl != null) {
          await Share.share(sheetUrl);
        } else if (context.mounted) {
          DialogUtils.showErrorDialog(context,
              message: 'Failed to create Google Sheet');
        }
        return;
      }

      if (format == ResultFormat.pdf) {
        final pdfData = _formattedPdf;
        final bytes = await pdfData.save();

        await Share.shareXFiles([
          XFile.fromData(
            bytes,
            name: 'race_results.pdf',
            mimeType: 'application/pdf',
          )
        ]);
        return;
      }

      // For plain text, use the formatted text
      await Share.share(_formattedResultsText);
    } catch (e) {
      if (context.mounted) {
        DialogUtils.showErrorDialog(context, message: 'Failed to share: $e');
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
      DialogUtils.showErrorDialog(context,
          message: 'Could not launch email client');
    }
  }

  // Helper method to encode query parameters
  String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}
