import 'dart:async';
import 'package:xceleration/utils/time_formatter.dart';

import '../../../utils/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../../../utils/sheet_utils.dart';
import '../../../../../utils/share_utils.dart';
import '../../../../../core/components/dialog_utils.dart';
import '../screen/share_race_screen.dart';
import '../../race_results/controller/race_results_controller.dart';
import '../../race_results/model/team_record.dart';

/// Controller class responsible for all sharing logic in the app
class ShareRaceController extends ChangeNotifier {
  late FormattedResultsController _formattedResultsController;
  late ShareResultsController _shareResultsController;

  ShareRaceController({
    required RaceResultsController controller,
  }) {
    _formattedResultsController = FormattedResultsController(controller: controller);
    _shareResultsController = ShareResultsController(
      formattedResultsController: _formattedResultsController,
    );
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

  /// Share the results
  Future<void> shareResults(
    BuildContext context,
    ResultFormat format,
  ) async {
    await _shareResultsController.shareResults(context, format);
  }
  
  /// Copy the results to clipboard
  Future<void> copyToClipboard(
    BuildContext context,
    ResultFormat format,
  ) async {
    await _shareResultsController.copyToClipboard(context, format);
  }

}

class ShareResultsController {
  late FormattedResultsController _formattedResultsController;
  late String title;

  ShareResultsController({
    required FormattedResultsController formattedResultsController,
  }) {
    _formattedResultsController = formattedResultsController;
    title = '${formattedResultsController.raceName} Results';
  }


  /// Copy the results to clipboard
  Future<void> copyToClipboard(
    BuildContext context,
    ResultFormat format,
  ) async {
    try {
      switch (format) {
        case ResultFormat.googleSheet:
          final sheetUri = await ShareUtils.createGoogleSheet(
            context,
            _formattedResultsController.formattedSheetsData,
            title,
          );
          if (sheetUri != null) {
            await Clipboard.setData(ClipboardData(text: sheetUri.toString()));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link Copied!')),
              );
            }
          } else if (context.mounted) {
            DialogUtils.showErrorDialog(context, 
                message: 'Failed to create Google Sheet');
          }
          break;

        case ResultFormat.pdf:
          DialogUtils.showErrorDialog(context,
              message:
                  'PDF format cannot be copied to clipboard. Please use Share option instead.');
          return;

        case ResultFormat.plainText:
          await Clipboard.setData(ClipboardData(text: _formattedResultsController.formattedResultsText));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Results Copied!')),
            );
          }
          break;
      }
    } catch (e) {
      if (context.mounted) {
        DialogUtils.showErrorDialog(context,
            message: 'Failed to copy to clipboard: $e');
      }
    }
  }

  /// Share results via Share.share
  Future<void> shareResults(
    BuildContext context,
    ResultFormat format,
  ) async {
    final share = SharePlus.instance;
    late ShareParams params;
    try {
      if (format == ResultFormat.googleSheet) {
        final sheetUri = await ShareUtils.createGoogleSheet(
          context,
          _formattedResultsController.formattedSheetsData,
          title,
        );
        if (sheetUri != null) {
          params = ShareParams(
            uri: sheetUri,
            subject: title,
            title: title,
          );
        } else if (context.mounted) {
          DialogUtils.showErrorDialog(context,
              message: 'Failed to create Google Sheet');
        }
      }

      if (format == ResultFormat.pdf) {
        final pdfData = _formattedResultsController.formattedPdf;
        DialogUtils.showLoadingDialog(context, message: 'Creating PDF...');
        final bytes = await pdfData.save();
        Navigator.of(context, rootNavigator: true).pop();

        final String pdfFileName = '$title.pdf';
        final xFile = XFile.fromData(
          bytes,
          name: pdfFileName,
          mimeType: 'application/pdf',
        );
        
        params = ShareParams(
          files: [xFile],
          subject: title,
          title: title,
          fileNameOverrides: [pdfFileName],
        );
      }

      if (format == ResultFormat.plainText) {
        params = ShareParams(
          text: _formattedResultsController.formattedResultsText,
          subject: title,
          title: title,
        );
      }

      await share.share(params);
    } catch (e) {
      if (context.mounted) {
        DialogUtils.showErrorDialog(context, message: 'Failed to share: $e');
      }
    }
  }
}


class FormattedResultsController {
  final RaceResultsController controller;
  late String formattedResultsText;
  late List<List<dynamic>> formattedSheetsData;
  late pw.Document formattedPdf;
  late String raceName;

  FormattedResultsController({
    required this.controller,
  }) {
    // Get race name from the database
    _initRaceName();
    formattedResultsText = _getFormattedText();
    formattedSheetsData = _getSheetsData();
    formattedPdf = _getPdfDocument();
  }
  
  void _initRaceName() {
    // Default fallback name in case we can't get the actual race name
    raceName = 'Race Results';
    
    // Try to get the actual race name from controller
    if (controller.raceName.isNotEmpty) {
      raceName = controller.raceName;
    }
  }

  // Text Formatting Methods
  String _getFormattedText() {
    final StringBuffer buffer = StringBuffer();

    // Team Results Section
    buffer.writeln('Team Results');
    buffer.writeln('Place\tSchool\tScore\tSplit Time\tAverage Time');
    for (final team in controller.overallTeamResults) {
      buffer.writeln('${team.place}\t${team.school}\t${team.score != 0 ? team.score : 'N/A'}\t'
          '${team.split != Duration.zero ? TimeFormatter.formatDuration(team.split) : 'N/A'}\t'
          '${team.avgTime != Duration.zero ? TimeFormatter.formatDuration(team.avgTime) : 'N/A'}');
    }

    // Individual Results Section
    buffer.writeln('\nIndividual Results');
    buffer.writeln('Place\tName\tSchool\tTime');
    for (final runner in controller.individualResults) {
      buffer.writeln('${runner.place}\t${runner.name}\t${runner.school}\t'
          '${TimeFormatter.formatDuration(runner.finishTime)}');
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
            team.scorers.isNotEmpty
                ? [
                    ...team.scorers.map((scorer) => scorer.place.toString()),
                    if (team.topSeven.length > 5) '(${team.topSeven.sublist(5, team.topSeven.length).map((runner) => runner.place.toString()).join(', ')})'
                  ].join(', ')
                : 'N/A',
            team.split != Duration.zero ? TimeFormatter.formatDuration(team.split) : 'N/A',
            team.avgTime != Duration.zero ? TimeFormatter.formatDuration(team.avgTime) : 'N/A',
          ]),

      // Spacing
      [],

      // Head-to-Head Team Results Sections
      if (controller.headToHeadTeamResults != null) ...[
        ...controller.headToHeadTeamResults!.expand((matchup) {
          final team1 = matchup[0];
          final team2 = matchup[1];

          // Get the max number of runners to show
          final maxRunners = team1.topSeven.length > team2.topSeven.length
              ? team1.topSeven.length
              : team2.topSeven.length;

          // Create a header for this matchup
          final matchupHeader = ['${team1.school} vs ${team2.school}', '', ''];

          // Create column headers
          final columnHeaders = ['', team1.school, team2.school];

          // Create data rows for each runner
          List<List<dynamic>> runnerRows = [];
          for (int i = 0; i < maxRunners; i++) {
            // Runner from first team (if exists)
            String team1Place =
                i < team1.topSeven.length ? '#${team1.topSeven[i].place}' : '';
            String team1Name =
                i < team1.topSeven.length ? team1.topSeven[i].name : '';

            // Runner from second team (if exists)
            String team2Place =
                i < team2.topSeven.length ? '#${team2.topSeven[i].place}' : '';
            String team2Name =
                i < team2.topSeven.length ? team2.topSeven[i].name : '';

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
                ? [
                    ...team.scorers.map((scorer) => scorer.place.toString()),
                    if (team.topSeven.length > 5) '(${team.topSeven.sublist(5, team.topSeven.length).map((runner) => runner.place.toString()).join(', ')})'
                  ].join(', ')
                : 'N/A',
                      team.split != Duration.zero
                          ? TimeFormatter.formatDuration(team.split)
                          : 'N/A',
                      team.avgTime != Duration.zero
                          ? TimeFormatter.formatDuration(team.avgTime)
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
                      TimeFormatter.formatDuration(runner.finishTime),
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
    final maxRunners = team1.topSeven.length > team2.topSeven.length
        ? team1.topSeven.length
        : team2.topSeven.length;

    for (int i = 0; i < maxRunners; i++) {
      // Runner from first team (if exists)
      String team1Place =
          i < team1.topSeven.length ? '#${team1.topSeven[i].place}' : '';
      String team1Name = i < team1.topSeven.length ? team1.topSeven[i].name : '';

      // Runner from second team (if exists)
      String team2Place =
          i < team2.topSeven.length ? '#${team2.topSeven[i].place}' : '';
      String team2Name = i < team2.topSeven.length ? team2.topSeven[i].name : '';

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
}