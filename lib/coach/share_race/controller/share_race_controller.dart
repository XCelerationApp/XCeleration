import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xceleration/utils/time_formatter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../utils/enums.dart';
import '../../race_results/model/team_record.dart';
import '../../race_results/model/results_record.dart';

import '../../../../../utils/sheet_utils.dart';
import '../../../../../utils/google_sheets_utils.dart';
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

  ShareResultsController({
    required FormattedResultsController formattedResultsController,
  }) {
    _formattedResultsController = formattedResultsController;
    title = '${formattedResultsController.raceName} Results';
  }


  /// Handle plain text format - copy to clipboard
  Future<void> _handlePlainTextCopy(BuildContext context) async {
    // Store navigator state early to handle context mounting issues
    // final navigatorState = Navigator.of(context, rootNavigator: true);
    // final globalContext = navigatorState.context;
    
    try {
      // Execute text preparation with loading dialog
      final success = await DialogUtils.executeWithLoadingDialog<bool>(
        context,
        loadingMessage: 'Preparing text...',
        operation: () async {
          // Get formatted text
          final plainText = await _formattedResultsController.formattedResultsText;
          
          // Copy to clipboard
          await Clipboard.setData(ClipboardData(text: plainText));
          
          return true;
        },
      );
      
      // Show success message if copying was successful
      if (success == true) {
        if (context.mounted) {
          // Use the scaffoldMessenger's context which has access to Overlay
          DialogUtils.showSuccessDialog(context, message: 'Results Copied!');
        }
      }
    } catch (e) {
      debugPrint('Error copying to clipboard: $e');
      
      // Only show error feedback if it's not a cancellation
      if (e is! OperationCanceledException) {
        // Use the scaffoldMessenger's context which has access to Overlay
        if (context.mounted) {
          DialogUtils.showErrorDialog(context, message: 'Failed to copy to clipboard');
        }
      }
    }
  }

  /// Handle Google Sheet - create sheet and show options using robust dialog
  Future<void> _handleGoogleSheet(BuildContext context) async {
        // Store navigator state early to handle context mounting issues
    final navigatorState = Navigator.of(context, rootNavigator: true);
    final globalContext = navigatorState.context;

    try {
      // Execute the sheet creation with a loading dialog
      final sheetUri = await DialogUtils.executeWithLoadingDialog<Uri>(
        globalContext,
        loadingMessage: 'Creating Google Sheet...',
        allowCancel: true, // Let user cancel if it's taking too long
        operation: () async {
          final List<List<dynamic>> data = await _formattedResultsController.formattedSheetsData;

          if (!globalContext.mounted) throw Exception('Context is not mounted');    
          // Create Google Sheet
          final uri = await GoogleSheetsUtils.createSheetAndGetUri(
            context: globalContext,
            title: title,
            data: data,
          );
          
          if (uri == null) {
            throw Exception('Failed to create Google Sheet');
          }
        
          return uri;
        },
      );

      debugPrint('Sheet URI: $sheetUri');
      
      // If sheet creation was successful, show options dialog using the stored navigator
      if (sheetUri != null) {
        if (globalContext.mounted) {
          await _showGoogleSheetOptions(globalContext, sheetUri);
        } else {
          _share(globalContext, ShareParams(
            text: sheetUri.toString(),
            subject: title,
            title: title,
          ));
          
        }
      }
    } catch (e) {
      debugPrint('Error in Google Sheet creation: $e');
      
      // Use the stored global context for showing error dialog
      if (context.mounted && e is! OperationCanceledException) {
        DialogUtils.showErrorDialog(context, message: 'Error creating Google Sheet');
      }
    }
  }
  
  /// Show options for Google Sheet (Copy Link, Open Sheet, Share)
  Future<void> _showGoogleSheetOptions(BuildContext context, Uri sheetUri) async {
    final result = await showGoogleSheetOptionsDialog(context, title: title, sheetUri: sheetUri);
    if (!context.mounted) return;
    // Handle the selected action if user selected an option
    if (result != null) {
      switch (result) {
        case GoogleSheetAction.openSheet:
          // Try to launch the URL in Google Sheets app first, fallback to browser
          final url = sheetUri.toString();
          
          try {
            // Check if we can launch with Google Sheets app scheme
            final sheetsAppUri = Uri.parse('googlesheetsapp://spreadsheets.google.com/d/$url');
            final canLaunchSheetsApp = await canLaunchUrl(sheetsAppUri);
            
            if (canLaunchSheetsApp) {
              debugPrint('Opening in Google Sheets app');
              // Open in Google Sheets app
              await launchUrl(sheetsAppUri);
            } else {
              debugPrint('Opening in browser');
              // Fallback to browser
              await launchUrl(
                sheetUri,
                mode: LaunchMode.externalApplication,
              );
            }
          } catch (e) {
            debugPrint('Error launching URL: $e');
            // Final fallback - try simple string launch
            try {
              await launchUrlString(url);
            } catch (e) {
              if (context.mounted) {
                DialogUtils.showErrorDialog(context, message: 'Unable to open Google Sheet');
              }
            }
          }
          break;
          
        case GoogleSheetAction.share:
          await _share(context, ShareParams(
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
          await _share(context, ShareParams(
            files: [xFile],
            subject: title,
            fileNameOverrides: [title],
            title: title,
          ));
        } else  {
          debugPrint('Context not mounted, PDF not shared');
        }
      }
    } catch (e) {
      debugPrint('Error in PDF creation: $e');
      
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
      debugPrint('Error sharing: $e');
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
  final Completer<List<List<dynamic>>> _sheetsDataCompleter = Completer<List<List<dynamic>>>();
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
      _formattedResultsText = await Future.microtask(() => _getFormattedText(controller));
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
      _formattedSheetsData = await Future.microtask(() => _getSheetsData(_SheetsDataParams(
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
      ['Place', 'School', 'Score', 'Scorers', 'Split Time', 'Average Time'],
      ...params.overallTeamResults.map((team) => [
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
      if (params.headToHeadTeamResults != null) ...[
        ...params.headToHeadTeamResults!.expand((matchup) {
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
      ...params.individualResults.map((runner) => [
            runner.place,
            runner.name,
            runner.school,
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
              'School',
              'Score',
              'Scorers',
              'Split Time',
              'Average Time'
            ],
            data: params.overallTeamResults
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
          if (params.headToHeadTeamResults != null) ...[
            pw.Header(level: 1, child: pw.Text('Head-to-Head Team Results')),
            pw.SizedBox(height: 10),

            // Generate each head-to-head matchup section
            for (final matchup in params.headToHeadTeamResults!) ...[
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
            data: params.individualResults
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