import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../coach/share_race/utils/url_launcher_helper.dart';
import '../../../coach/share_race/widgets/google_sheet_dialog_widgets.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../core/result.dart';
import '../../../core/utils/google_sheets_service.dart';
import '../../../core/utils/i_google_sheets_service.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/sheet_utils.dart';
import '../models/race_record.dart';
import '../widgets/download_race_sheet.dart';
import 'assistant_export_service.dart';

/// "Download a Copy" from the Timer or Bib Recorder menu: asks how, then
/// copies the race as text, makes a Google Sheet of it, or shares a CSV or
/// PDF file.
///
/// [what] names the list ("Finish Times", "Bib Numbers"), [table] is it as
/// rows under a heading row, and [exportFile] writes it as a file.
Future<void> saveRaceCopy(
  BuildContext context, {
  required RaceRecord race,
  required String what,
  required List<List<String>> table,
  required Future<Result<XFile>> Function(DownloadFormat format) exportFile,
  IGoogleSheetsService? sheets,
}) async {
  final dynamic picked = await sheet(
    context: context,
    title: 'Download a Copy',
    body: const DownloadRaceSheet(),
  );
  final format = picked is DownloadFormat ? picked : null;
  if (format == null || !context.mounted) return;

  switch (format) {
    case DownloadFormat.text:
      await _copyAsText(context, race, table);
    case DownloadFormat.sheets:
      await _makeGoogleSheet(context, race, what, table,
          sheets ?? GoogleSheetsService.instance);
    case DownloadFormat.csv:
    case DownloadFormat.pdf:
      await _shareFile(context, race, () => exportFile(format));
  }
}

Future<void> _copyAsText(
  BuildContext context,
  RaceRecord race,
  List<List<String>> table,
) async {
  try {
    await Clipboard.setData(
        ClipboardData(text: AssistantExportService.asText(race, table)));
    if (context.mounted) {
      DialogUtils.showSuccessDialog(context, message: 'Copied');
    }
  } catch (e) {
    Logger.e('Error copying race: $e');
    if (context.mounted) {
      DialogUtils.showErrorDialog(context, message: 'Could not copy.');
    }
  }
}

Future<void> _makeGoogleSheet(
  BuildContext context,
  RaceRecord race,
  String what,
  List<List<String>> table,
  IGoogleSheetsService sheets,
) async {
  final title = AssistantExportService.sheetTitle(race, what);
  Uri? uri;
  var failed = false;
  try {
    uri = await DialogUtils.executeWithLoadingDialog<Uri?>(
      context,
      loadingMessage: 'Making a Google Sheet...',
      operation: () async {
        if (!await sheets.signIn()) throw Exception('Google sign-in failed');
        final id = await sheets.createSheet(title: title);
        if (id == null) throw Exception('Could not create the sheet');
        if (!await sheets.updateSheet(spreadsheetId: id, data: table)) {
          throw Exception('Could not fill in the sheet');
        }
        return sheets.getSheetUri(id);
      },
    );
  } catch (e) {
    Logger.e('Error making Google Sheet: $e');
    failed = true;
  }
  if (!context.mounted) return;
  if (failed) {
    DialogUtils.showErrorDialog(context,
        message: 'Could not make a Google Sheet. Check you are online and '
            'signed in to Google.');
    return;
  }
  // Cancelled from the loading dialog: nothing to say.
  if (uri == null) return;

  final action =
      await showGoogleSheetOptionsDialog(context, title: title, sheetUri: uri);
  if (!context.mounted) return;
  switch (action) {
    case GoogleSheetAction.openSheet:
      await UrlLauncherHelper.launchSheetUrl(context, uri);
    case GoogleSheetAction.share:
      await SharePlus.instance
          .share(ShareParams(text: uri.toString(), subject: title));
    case GoogleSheetAction.copyLink:
    case null:
      break;
  }
}

Future<void> _shareFile(
  BuildContext context,
  RaceRecord race,
  Future<Result<XFile>> Function() exportFile,
) async {
  final xFile = await DialogUtils.executeWithLoadingDialog<XFile>(
    context,
    loadingMessage: 'Preparing download...',
    operation: () async {
      return switch (await exportFile()) {
        Success(:final value) => value,
        Failure(:final error) => throw Exception(error.userMessage),
      };
    },
  );
  if (xFile == null || !context.mounted) return;

  try {
    await AssistantExportService.shareFile(xFile, race.name);
  } catch (e) {
    Logger.e('Error sharing race download: $e');
    if (context.mounted) {
      DialogUtils.showErrorDialog(context, message: 'Failed to share file.');
    }
  }
}
