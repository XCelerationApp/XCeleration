import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'google_sheets_service.dart';
import 'google_drive_service.dart';

/// A service that handles picking files from Google Drive using Google's native
/// Picker API for desktop/mobile apps (OAuth redirect flow, currently in beta).
///
/// ## Architecture overview
///
/// Rather than embedding the Google Picker JS (which requires cross-origin iframes
/// and is blocked by ITP in all iOS embedded browsers), this implementation uses
/// Google's newer OAuth-redirect-based picker flow. The file picker UI is shown
/// inside the OAuth authorization screen, opened via ASWebAuthenticationSession
/// on iOS.
///
/// ## Flow
///
/// 1. Build an OAuth authorization URL with `trigger_onepick=true` and
///    `mimetypes=` filtering for spreadsheet types.
/// 2. Open the URL in ASWebAuthenticationSession via `flutter_web_auth_2`.
///    The session shares Safari's cookie store — if the user is already signed
///    into Google in Safari, the sign-in step may be skipped.
/// 3. After the user selects a file, Google redirects to the registered
///    `redirect_uri` (`xcelerationapp://picker`) with
///    `picked_file_ids=FILE_ID&code=AUTH_CODE`. ASWebAuthenticationSession
///    automatically intercepts the redirect and returns the full callback URL.
/// 4. The file ID is extracted from the callback. Drive REST API metadata is then
///    fetched using the existing `iosAccessToken` to obtain the file name and
///    MIME type needed for download.
///
/// ## Setup requirements
///
/// Uses the iOS OAuth client (`GOOGLE_IOS_OAUTH_CLIENT_ID`). The reverse-DNS
/// redirect URI scheme (`com.googleusercontent.apps.<ID>:/oauthredirect`) is
/// pre-configured on iOS OAuth clients in Google Cloud Console and is already
/// registered in `ios/Runner/Info.plist` — no Cloud Console changes needed.
///
/// ## Auth note
///
/// Refresh tokens are not supported for reopening the Picker UI — the user must
/// go through the OAuth flow each time they pick a file. The `code` returned in
/// the callback can optionally be exchanged for tokens to access the picked file,
/// but the existing `iosAccessToken` (from `google_sign_in`) is used instead
/// since both carry `drive.file` scope for the same user.
class GooglePickerService {
  static GooglePickerService? _instance;
  static GooglePickerService get instance =>
      _instance ??= GooglePickerService._();

  final GoogleSheetsService _sheetsService = GoogleSheetsService.instance;
  final GoogleDriveService _driveService = GoogleDriveService.instance;

  static String get _clientId =>
      dotenv.env['GOOGLE_IOS_OAUTH_CLIENT_ID'] ?? '';

  /// Derives the reverse-DNS URL scheme from the full iOS OAuth client ID.
  /// e.g. "529...3.apps.googleusercontent.com" → "com.googleusercontent.apps.529...3"
  static String _callbackScheme(String iosClientId) {
    const suffix = '.apps.googleusercontent.com';
    if (!iosClientId.endsWith(suffix)) return iosClientId;
    final id = iosClientId.substring(0, iosClientId.length - suffix.length);
    return 'com.googleusercontent.apps.$id';
  }

  static const _mimeTypes =
      'application/vnd.google-apps.spreadsheet,'
      'application/vnd.ms-excel,'
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,'
      'text/csv';

  GooglePickerService._();

  /// Opens the Google Drive file picker via ASWebAuthenticationSession.
  ///
  /// Uses Google's native Picker OAuth redirect flow (`trigger_onepick=true`),
  /// which shows the file browser inside the OAuth authorization screen — no
  /// iframes, no cross-origin cookies, no ITP issues.
  ///
  /// Returns a map with `action` set to `'picked'`, `'canceled'`, or `'error'`.
  /// On `'picked'`, the map contains `'data'` with the `id` of the selected
  /// file. Name and MIME type are resolved separately via the Drive API in
  /// [pickGoogleDriveFile].
  static Future<Map<String, dynamic>?> showPicker(
      {required BuildContext context}) async {
    final clientId = _clientId;
    if (clientId.isEmpty) {
      Logger.e('[Picker] GOOGLE_IOS_OAUTH_CLIENT_ID is not set');
      return {'action': 'error', 'message': 'Google Authentication Failed'};
    }

    final scheme = _callbackScheme(clientId);
    final redirectUri = '$scheme:/oauthredirect';

    final uri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'https://www.googleapis.com/auth/drive.file',
      'trigger_onepick': 'true',
      'mimetypes': _mimeTypes,
    });

    Logger.d('Opening Google Picker via ASWebAuthenticationSession');

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: uri.toString(),
        callbackUrlScheme: scheme,
      );

      final callbackUri = Uri.parse(result);
      final error = callbackUri.queryParameters['error'];

      if (error != null) {
        Logger.d('[Picker] OAuth error: $error');
        if (error == 'access_denied') {
          return {'action': 'canceled'};
        }
        return {'action': 'error', 'message': error};
      }

      final fileIdsParam = callbackUri.queryParameters['picked_file_ids'];
      Logger.d('[Picker] picked_file_ids: $fileIdsParam');

      if (fileIdsParam == null || fileIdsParam.isEmpty) {
        return {'action': 'canceled'};
      }

      final fileId = fileIdsParam.split(',').first.trim();
      return {'action': 'picked', 'data': {'id': fileId}};
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') {
        Logger.d('[Picker] User canceled ASWebAuthenticationSession');
        return {'action': 'canceled'};
      }
      Logger.e('[Picker] PlatformException: ${e.code} — ${e.message}');
      return {'action': 'error', 'message': e.message ?? 'Unknown error'};
    } catch (e) {
      Logger.e('[Picker] Unexpected error: $e');
      return {'action': 'error'};
    }
  }

  /// Opens a file picker that allows the user to select a file from Google Drive.
  /// Returns the selected file as a temporary file downloaded to the device.
  /// Only allows selection of spreadsheet files (Google Sheets, CSV, XLSX).
  Future<File?> pickGoogleDriveFile(BuildContext context) async {
    try {
      Logger.d('Proceeding with Google Drive picker');

      Map<String, dynamic>? pickerResult;
      if (context.mounted) {
        pickerResult = await GooglePickerService.showPicker(context: context);
      }

      if (pickerResult == null || pickerResult['action'] != 'picked') {
        if (pickerResult != null && pickerResult['action'] == 'canceled') {
          Logger.d('User canceled Google Drive picker');
        } else {
          Logger.e('Error picking file: $pickerResult');
          if (context.mounted) {
            String message = 'Error in Picking Spreadsheet from Google Drive';
            if (pickerResult != null && pickerResult['message'] != null) {
              message += ': ${pickerResult['message']}';
            }
            DialogUtils.showErrorDialog(context, message: message);
          }
        }
        return null;
      }

      final doc = pickerResult['data'] as Map<String, dynamic>?;
      if (doc == null) {
        Logger.d('No document data in picker result');
        return null;
      }

      final fileId = doc['id'] as String?;
      if (fileId == null) {
        Logger.d('Invalid document data: $doc');
        return null;
      }

      // The new picker only returns file IDs — fetch name and MIME type from
      // the Drive API before proceeding with download.
      final fileInfo = await _driveService.getFileInfo(fileId);
      final fileName = fileInfo?.name;
      final mimeType = fileInfo?.mimeType;

      Logger.d(
          'Selected file: id=$fileId, name=$fileName, mimeType=$mimeType');

      if (fileName == null || mimeType == null) {
        Logger.e('Failed to get file metadata for: $fileId');
        if (context.mounted) {
          DialogUtils.showErrorDialog(context,
              message:
                  'Could not read file information. Please try again.');
        }
        return null;
      }

      if (!_isSupportedFileType(mimeType, fileName)) {
        Logger.d('Unsupported file type: $fileName');
        if (context.mounted) {
          DialogUtils.showErrorDialog(
            context,
            message:
                'File format not supported. Please select a spreadsheet file (XLSX, CSV, XLS, or Google Sheet).',
          );
        }
        return null;
      }

      try {
        if (mimeType == 'application/vnd.google-apps.spreadsheet') {
          Logger.d('Using GoogleSheetsService for downloading Google Sheet');
          if (context.mounted) {
            return await _sheetsService.downloadGoogleSheet(
              fileId: fileId,
              fileName: fileName,
              context: context,
            );
          }
          return null;
        }

        if (context.mounted) {
          final tempFile = await DialogUtils.executeWithLoadingDialog<File?>(
            context,
            loadingMessage: 'Downloading file from Google Drive...',
            operation: () => _driveService.downloadFile(fileId, fileName),
            allowCancel: true,
          );

          if (tempFile != null) {
            return tempFile;
          }
        }

        return null;
      } catch (e) {
        Logger.e('Error downloading file: $e');
        if (context.mounted) {
          DialogUtils.showErrorDialog(
            context,
            message:
                'Download Failed: Could not download the selected file. Please try again.',
          );
        }
        return null;
      }
    } catch (e) {
      Logger.e('Error in picker process: $e');
      if (context.mounted) {
        DialogUtils.showErrorDialog(
          context,
          message:
              'An error occurred while selecting the file. Please try again.',
        );
      }
      return null;
    }
  }

  bool _isSupportedFileType(String mimeType, String fileName) {
    if (mimeType == 'application/vnd.google-apps.spreadsheet') return true;

    if (mimeType.contains('excel') ||
        mimeType ==
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
        mimeType == 'application/vnd.ms-excel') {
      return true;
    }

    if (mimeType == 'text/csv' || fileName.toLowerCase().endsWith('.csv')) {
      return true;
    }

    if (fileName.toLowerCase().endsWith('.xlsx') ||
        fileName.toLowerCase().endsWith('.xls') ||
        fileName.toLowerCase().endsWith('.ods')) {
      return true;
    }

    if (fileName.toLowerCase().endsWith('.gsheet') ||
        fileName.toLowerCase().endsWith('.gsf')) {
      return true;
    }

    return false;
  }
}
