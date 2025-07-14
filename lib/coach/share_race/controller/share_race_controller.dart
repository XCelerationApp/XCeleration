import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:flutter/services.dart';
import 'package:xceleration/core/utils/time_formatter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../core/utils/enums.dart';
import '../../race_results/model/team_record.dart';
import '../../race_results/model/results_record.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../core/utils/google_sheets_service.dart';
import '../../../../../core/components/dialog_utils.dart';
import '../screen/share_race_screen.dart';
import '../../race_results/controller/race_results_controller.dart';
import '../widgets/google_sheet_dialog_widgets.dart';

/// Controller class responsible for all sharing logic in the app
class ShareRaceController extends ChangeNotifier {
  late FormattedResultsController _formattedResultsController;
  late ShareResultsController _shareResultsController;

  ShareRaceController({
    required RaceResultsController controller,
  }) {
    _formattedResultsController =
        FormattedResultsController(controller: controller);
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

  /// Share results using the specified format
  Future<void> shareResults(BuildContext context, ResultFormat format) async {
    switch (format) {
      case ResultFormat.plainText:
        // Plain text is typically only copied, not shared
        await _shareResultsController._handlePlainTextCopy(context);
        break;
      case ResultFormat.googleSheet:
        await _shareResultsController._handleGoogleSheet(context);
        break;
      case ResultFormat.pdf:
        await _shareResultsController._handlePdf(context);
        break;
    }

    notifyListeners();
  }
}

class ShareResultsController {
  late FormattedResultsController _formattedResultsController;
  late String title;
  final GoogleSheetsService _googleSheetsService = GoogleSheetsService.instance;

  ShareResultsController({
    required FormattedResultsController formattedResultsController,
  }) {
    _formattedResultsController = formattedResultsController;
    title = '${formattedResultsController.raceName} Results';
  }

  /// Handle plain text format - copy to clipboard
  Future<void> _handlePlainTextCopy(BuildContext context) async {
    // Grab a reference to the Navigator **not** the BuildContext so we don't
    // keep a `BuildContext` alive across the async gap.
    final navigator = Navigator.of(context, rootNavigator: true);

    try {
      // Execute text preparation with loading dialog
      final success = await DialogUtils.executeWithLoadingDialog<bool>(
        context,
        loadingMessage: 'Preparing text...',
        operation: () async {
          // Get formatted text
          final plainText =
              await _formattedResultsController.formattedResultsText;

          // Copy to clipboard
          await Clipboard.setData(ClipboardData(text: plainText));

          return true;
        },
      );

      if (!context.mounted) context = navigator.context;

      // Show success message if copying was successful
      if (success == true) {
        if (context.mounted) {
          // Use the scaffoldMessenger's context which has access to Overlay
          DialogUtils.showSuccessDialog(context, message: 'Results Copied!');
        }
      }
    } catch (e) {
      Logger.d('Error copying to clipboard: $e');

      // Only show error feedback if it's not a cancellation
      if (e is! OperationCanceledException) {
        // Use the scaffoldMessenger's context which has access to Overlay
        if (context.mounted) {
          DialogUtils.showErrorDialog(context,
              message: 'Failed to copy to clipboard');
        }
      }
    }
  }

  /// Handle Google Sheet - create sheet and show options using robust dialog
  Future<void> _handleGoogleSheet(BuildContext context) async {
    // Grab a reference to the Navigator **not** the BuildContext so we don't
    // keep a `BuildContext` alive across the async gap.
    if (!context.mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);

    try {
      // Get formatted data first
      final data = await _formattedResultsController.formattedSheetsData;

      if (!context.mounted) context = navigator.context;
      if (!context.mounted) throw Exception('Context not mounted');

      // Step 1: Sign in to Google with loading dialog
      try {
        if (!await _googleSheetsService.signIn()) {
          if (context.mounted) {
            DialogUtils.showErrorDialog(context,
                message: 'Google sign-in failed');
          }
          return;
        }
      } catch (e) {
        Logger.e('Error signing in to Google: $e');
        if (context.mounted) {
          DialogUtils.showErrorDialog(context,
              message: 'Error signing in to Google');
        }
        return;
      }

      if (!context.mounted) context = navigator.context;
      if (!context.mounted) throw Exception('Context not mounted');

      // Step 2: Create the sheet with loading dialog
      // We need to declare the variable here so it can be used outside the try/catch block
      String? spreadsheetId;
      try {
        spreadsheetId = await DialogUtils.executeWithLoadingDialog<String?>(
          context,
          operation: () => _googleSheetsService.createSheet(title: title),
          loadingMessage: 'Creating Google Sheet...',
        );
        if (spreadsheetId == null) {
          // If the user cancels the creation, we don't want to continue, but no need to show an error dialog
          return;
        }
      } catch (e) {
        Logger.e('Error creating Google Sheet: $e');
        if (context.mounted) {
          DialogUtils.showErrorDialog(context,
              message: 'Error creating Google Sheet');
        }
        return;
      }

      if (!context.mounted) context = navigator.context;
      if (!context.mounted) throw Exception('Context not mounted');

      // Step 3: Update the sheet with data
      try {
        final updateSuccess = await DialogUtils.executeWithLoadingDialog<bool>(
          context,
          operation: () => _googleSheetsService.updateSheet(
            spreadsheetId: spreadsheetId!,
            data: data,
          ),
          loadingMessage: 'Adding data to sheet...',
        );
        if (updateSuccess == null) {
          // If the user cancels the update, we don't want to continue, but no need to show an error dialog
          return;
        }
        if (updateSuccess != true) {
          if (context.mounted) {
            DialogUtils.showErrorDialog(context,
                message: 'Failed to write to Google Sheet');
          }
          return;
        }
      } catch (e) {
        Logger.e('Error writing to Google Sheet: $e');
        if (context.mounted) {
          DialogUtils.showErrorDialog(context,
              message: 'Error writing to Google Sheet');
        }
        return;
      }

      if (!context.mounted) context = navigator.context;
      if (!context.mounted) throw Exception('Context not mounted');
      // Step 4: Get the sheet URI
      // We need to declare the variable here so it can be used outside the try/catch block
      Uri? sheetUri;
      try {
        sheetUri = await DialogUtils.executeWithLoadingDialog<Uri?>(
          context,
          operation: () => _googleSheetsService.getSheetUri(spreadsheetId!),
          loadingMessage: 'Getting sheet link...',
        );
        if (sheetUri == null) {
          // If the user cancels the creation, we don't want to continue, but no need to show an error dialog
          return;
        }
      } catch (e) {
        Logger.e('Error getting sheet URI: $e');
        if (context.mounted) {
          DialogUtils.showErrorDialog(
            context,
            message: 'Error getting sheet link',
          );
        }
        return;
      }

      Logger.d('Sheet URI: $sheetUri');

      if (!context.mounted) context = navigator.context;

      // Show options dialog using the stored navigator
      if (context.mounted) {
        await _showGoogleSheetOptions(context, sheetUri);
      } else {
        Logger.d('Context not mounted, skipping Google Sheet options');
        await Clipboard.setData(ClipboardData(text: sheetUri.toString()));
        Logger.d('Sheet URL copied to clipboard');
        if (context.mounted) {
          DialogUtils.showSuccessDialog(context,
              message: 'Sheet URL copied to clipboard');
        }
      }
    } catch (e) {
      Logger.d('Error in Google Sheet creation: $e');

      // Use the stored global context for showing error dialog
      if (context.mounted && e is! OperationCanceledException) {
        DialogUtils.showErrorDialog(context,
            message: 'Error creating Google Sheet');
      }
    }
  }

  /// Show options for Google Sheet (Copy Link, Open Sheet, Share)
  Future<void> _showGoogleSheetOptions(
      BuildContext context, Uri sheetUri) async {
    final result = await showGoogleSheetOptionsDialog(context,
        title: title, sheetUri: sheetUri);
    if (!context.mounted) return;
    // Handle the selected action if user selected an option
    if (result != null) {
      switch (result) {
        case GoogleSheetAction.openSheet:
          // Try to launch the URL in Google Sheets app first, fallback to browser
          final url = sheetUri.toString();

          try {
            // Check if we can launch with Google Sheets app scheme
            final sheetsAppUri =
                Uri.parse('googlesheetsapp://spreadsheets.google.com/d/$url');
            final canLaunchSheetsApp = await canLaunchUrl(sheetsAppUri);

            if (canLaunchSheetsApp) {
              Logger.d('Opening in Google Sheets app');
              // Open in Google Sheets app
              await launchUrl(sheetsAppUri);
            } else {
              Logger.d('Opening in browser');
              // Fallback to browser
              await launchUrl(
                sheetUri,
                mode: LaunchMode.externalApplication,
              );
            }
          } catch (e) {
            Logger.d('Error launching URL: $e');
            // Final fallback - try simple string launch
            try {
              await launchUrlString(url);
            } catch (e) {
              if (context.mounted) {
                DialogUtils.showErrorDialog(context,
                    message: 'Unable to open Google Sheet');
              }
            }
          }
          break;

        case GoogleSheetAction.share:
          await _share(
              context,
              ShareParams(
                text: sheetUri.toString(),
                subject: title,
                title: title,
              ));
          break;

        // Copy Link action is now handled directly in the button's onPressed callback
        case GoogleSheetAction.copyLink:
          // This shouldn't happen since we're handling the copy action in the button
          // But kept for completeness
          break;
      }
    }
  }

  /// Handle PDF - create and share immediately
  Future<void> _handlePdf(BuildContext context) async {
    try {
      // Execute PDF creation with loading dialog
      final xFile = await DialogUtils.executeWithLoadingDialog<XFile>(
        context,
        loadingMessage: 'Creating PDF...',
        allowCancel: true,
        operation: () async {
          // Generate PDF data
          final pdfData = await _formattedResultsController.formattedPdf;

          // Save PDF to bytes
          final bytes = await pdfData.save();

          // Create PDF file for sharing
          final String pdfFileName = '$title.pdf';
          return XFile.fromData(
            bytes,
            name: pdfFileName,
            mimeType: 'application/pdf',
          );
        },
      );

      // Share PDF if creation was successful
      if (xFile != null) {
        if (context.mounted) {
          await _share(
              context,
              ShareParams(
                files: [xFile],
                subject: title,
                fileNameOverrides: [title],
                title: title,
              ));
        } else {
          Logger.d('Context not mounted, PDF not shared');
        }
      }
    } catch (e) {
      Logger.d('Error in PDF creation: $e');

      // Only show error dialog if context is still mounted and it's not a cancellation
      if (context.mounted && e is! OperationCanceledException) {
        DialogUtils.showErrorDialog(context, message: 'Error creating PDF');
      }
    }
  }

  /// Generic share function
  Future<void> _share(BuildContext context, ShareParams params) async {
    SharePlus share = SharePlus.instance;
    try {
      await share.share(
        params,
      );
    } catch (e) {
      Logger.d('Error sharing: $e');
      if (context.mounted) {
        DialogUtils.showErrorDialog(context, message: 'Failed to share');
      }
    }
  }
}

// Parameter classes for isolate computation
class _SheetsDataParams {
  final List<TeamRecord> overallTeamResults;
  final List<List<TeamRecord>>? headToHeadTeamResults;
  final List<ResultsRecord> individualResults;

  _SheetsDataParams({
    required this.overallTeamResults,
    required this.headToHeadTeamResults,
    required this.individualResults,
  });
}

class _PdfParams {
  final List<TeamRecord> overallTeamResults;
  final List<List<TeamRecord>>? headToHeadTeamResults;
  final List<ResultsRecord> individualResults;
  final String raceName;

  _PdfParams({
    required this.overallTeamResults,
    required this.headToHeadTeamResults,
    required this.individualResults,
    required this.raceName,
  });
}

class FormattedResultsController {
  final RaceResultsController controller;
  String? _formattedResultsText;
  List<List<dynamic>>? _formattedSheetsData;
  pw.Document? _formattedPdf;
  late String raceName;

  // Completer objects to prevent multiple simultaneous generations
  final Completer<String> _textCompleter = Completer<String>();
  final Completer<List<List<dynamic>>> _sheetsDataCompleter =
      Completer<List<List<dynamic>>>();
  final Completer<pw.Document> _pdfCompleter = Completer<pw.Document>();

  // Track whether generation processes have been initiated
  bool _textGenerationStarted = false;
  bool _sheetsDataGenerationStarted = false;
  bool _pdfGenerationStarted = false;

  FormattedResultsController({
    required this.controller,
  }) {
    // Only initialize the race name in constructor
    _initRaceName();
  }

  void _initRaceName() {
    // Default fallback name in case we can't get the actual race name
    raceName = 'Race Results';

    // Try to get the actual race name from controller
    if (controller.raceName.isNotEmpty) {
      raceName = controller.raceName;
    }
  }

  // Async getters that lazily initialize and cache results
  Future<String> get formattedResultsText async {
    if (_formattedResultsText != null) {
      return _formattedResultsText!;
    }

    if (_textGenerationStarted) {
      return _textCompleter.future;
    }

    _textGenerationStarted = true;
    try {
      // Generate text asynchronously in a microtask to avoid blocking the UI
      _formattedResultsText =
          await Future.microtask(() => _getFormattedText(controller));
      if (!_textCompleter.isCompleted) {
        _textCompleter.complete(_formattedResultsText);
      }
      return _formattedResultsText!;
    } catch (e) {
      if (!_textCompleter.isCompleted) {
        _textCompleter.completeError(e);
      }
      rethrow;
    }
  }

  // Text Formatting Methods - Made static for compute() function
  static String _getFormattedText(RaceResultsController controller) {
    final StringBuffer buffer = StringBuffer();

    // Team Results Section
    buffer.writeln('Team Results');
    buffer.writeln('PlaceTeam\tScore\tSplit Time\tAverage Time');
    for (final team in controller.overallTeamResults) {
      buffer.writeln(
          '${team.place}\t${team.teamAbbreviation}\t${team.score != 0 ? team.score : 'N/A'}\t'
          '${team.split != Duration.zero ? TimeFormatter.formatDuration(team.split) : 'N/A'}\t'
          '${team.avgTime != Duration.zero ? TimeFormatter.formatDuration(team.avgTime) : 'N/A'}');
    }

    // Individual Results Section
    buffer.writeln('\nIndividual Results');
    buffer.writeln('Place\tNameTeam\tTime');
    for (final runner in controller.individualResults) {
      buffer.writeln(
          '${runner.place}\t${runner.name}\t${runner.teamAbbreviation}\t'
          '${TimeFormatter.formatDuration(runner.finishTime)}');
    }

    return buffer.toString();
  }

  // Async getter for sheets data
  Future<List<List<dynamic>>> get formattedSheetsData async {
    if (_formattedSheetsData != null) {
      return _formattedSheetsData!;
    }

    if (_sheetsDataGenerationStarted) {
      return _sheetsDataCompleter.future;
    }

    _sheetsDataGenerationStarted = true;
    try {
      // Process asynchronously in a microtask to avoid blocking the UI
      _formattedSheetsData =
          await Future.microtask(() => _getSheetsData(_SheetsDataParams(
                overallTeamResults: controller.overallTeamResults,
                headToHeadTeamResults: controller.headToHeadTeamResults,
                individualResults: controller.individualResults,
              )));
      if (!_sheetsDataCompleter.isCompleted) {
        _sheetsDataCompleter.complete(_formattedSheetsData);
      }
      return _formattedSheetsData!;
    } catch (e) {
      if (!_sheetsDataCompleter.isCompleted) {
        _sheetsDataCompleter.completeError(e);
      }
      rethrow;
    }
  }

  // Data Formatting Methods - Made static for compute() function
  static List<List<dynamic>> _getSheetsData(_SheetsDataParams params) {
    final List<List<dynamic>> sheetsData = [
      // Team Results Section
      ['Team Results'],
      ['Place', 'Team', 'Score', 'Scorers', 'Split Time', 'Average Time'],
      ...params.overallTeamResults.map((team) => [
            team.place,
            team.teamAbbreviation,
            team.score != 0 ? team.score : 'N/A',
            team.scorers.isNotEmpty
                ? [
                    ...team.scorers.map((scorer) => scorer.place.toString()),
                    if (team.topSeven.length > 5)
                      '(${team.topSeven.sublist(5, team.topSeven.length).map((runner) => runner.place.toString()).join(', ')})'
                  ].join(', ')
                : 'N/A',
            team.split != Duration.zero
                ? TimeFormatter.formatDuration(team.split)
                : 'N/A',
            team.avgTime != Duration.zero
                ? TimeFormatter.formatDuration(team.avgTime)
                : 'N/A',
          ]),

      // Spacing
      [],

      // Head-to-Head Team Results Sections
      if (params.headToHeadTeamResults != null) ...[
        ...params.headToHeadTeamResults!.expand((matchup) {
          final team1 = matchup[0];
          final team2 = matchup[1];

          // Get the max number of runners to show
          final maxRunners = team1.topSeven.length > team2.topSeven.length
              ? team1.topSeven.length
              : team2.topSeven.length;

          // Create a header for this matchup
          final matchupHeader = ['${team1.team} vs ${team2.team}', '', ''];

          // Create column headers
          final columnHeaders = ['', team1.team, team2.team];

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
          final summaryRow = [
            'Score',
            '${team1.score != 0 ? team1.score : 'N/A'}',
            '${team2.score != 0 ? team2.score : 'N/A'}'
          ];

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
      ['Place', 'Name', 'Team', 'Time'],
      ...params.individualResults.map((runner) => [
            runner.place,
            runner.name,
            runner.teamAbbreviation,
            runner.finishTime,
          ]),
    ];

    return sheetsData;
  }

  // Async getter for PDF document
  Future<pw.Document> get formattedPdf async {
    if (_formattedPdf != null) {
      return _formattedPdf!;
    }

    if (_pdfGenerationStarted) {
      return _pdfCompleter.future;
    }

    _pdfGenerationStarted = true;
    try {
      // Process asynchronously in a microtask to avoid blocking the UI
      _formattedPdf = await Future.microtask(() => _getPdfDocument(_PdfParams(
            overallTeamResults: controller.overallTeamResults,
            headToHeadTeamResults: controller.headToHeadTeamResults,
            individualResults: controller.individualResults,
            raceName: raceName,
          )));
      if (!_pdfCompleter.isCompleted) {
        _pdfCompleter.complete(_formattedPdf);
      }
      return _formattedPdf!;
    } catch (e) {
      if (!_pdfCompleter.isCompleted) {
        _pdfCompleter.completeError(e);
      }
      rethrow;
    }
  }

  // Static method for PDF generation - made static for compute() function
  static pw.Document _getPdfDocument(_PdfParams params) {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          // Title
          pw.Header(
            level: 0,
            child: pw.Text(params.raceName, style: pw.TextStyle(fontSize: 24)),
          ),

          // Team Results Section
          pw.Header(level: 1, child: pw.Text('Team Results')),
          pw.TableHelper.fromTextArray(
            headers: [
              'Place',
              'Team',
              'Score',
              'Scorers',
              'Split Time',
              'Average Time'
            ],
            data: params.overallTeamResults
                .map((team) => [
                      team.place.toString(),
                      team.teamAbbreviation,
                      team.score != 0 ? team.score.toString() : 'N/A',
                      team.scorers.isNotEmpty
                          ? [
                              ...team.scorers
                                  .map((scorer) => scorer.place.toString()),
                              if (team.topSeven.length > 5)
                                '(${team.topSeven.sublist(5, team.topSeven.length).map((runner) => runner.place.toString()).join(', ')})'
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
          if (params.headToHeadTeamResults != null) ...[
            pw.Header(level: 1, child: pw.Text('Head-to-Head Team Results')),
            pw.SizedBox(height: 10),

            // Generate each head-to-head matchup section
            for (final matchup in params.headToHeadTeamResults!) ...[
              pw.Header(
                  level: 2,
                  child: pw.Text('${matchup[0].team} vs ${matchup[1].team}')),

              // Table with the results
              pw.TableHelper.fromTextArray(
                headers: ['', matchup[0].team, matchup[1].team],
                data: _generateHeadToHeadRows(matchup[0], matchup[1]),
              ),

              pw.SizedBox(height: 20),
            ],
          ],

          pw.SizedBox(height: 20),

          // Individual Results Section
          pw.Header(level: 1, child: pw.Text('Individual Results')),
          pw.TableHelper.fromTextArray(
            headers: ['Place', 'Name', 'Team', 'Time'],
            data: params.individualResults
                .map((runner) => [
                      runner.place.toString(),
                      runner.name.toString(),
                      runner.teamAbbreviation,
                      TimeFormatter.formatDuration(runner.finishTime),
                    ])
                .toList(),
          ),
        ],
      ),
    );

    return pdf;
  }

  static List<List<String>> _generateHeadToHeadRows(
      TeamRecord team1, TeamRecord team2) {
    final List<List<String>> rows = [];
    final maxRunners = team1.topSeven.length > team2.topSeven.length
        ? team1.topSeven.length
        : team2.topSeven.length;

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

      rows.add([
        '${i + 1}',
        team1Place.isNotEmpty ? '$team1Place $team1Name' : '',
        team2Place.isNotEmpty ? '$team2Place $team2Name' : ''
      ]);
    }

    // Add summary row
    rows.add([
      'Score',
      '${team1.score != 0 ? team1.score : 'N/A'}',
      '${team2.score != 0 ? team2.score : 'N/A'}'
    ]);

    return rows;
  }
}
