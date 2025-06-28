import 'dart:io';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'google_auth_service.dart';
import 'google_picker_service.dart';
import 'package:path_provider/path_provider.dart';

/// Service for interacting with Google Drive API with drive.file scope
/// This implementation uses GooglePickerService to select files
/// and only accesses files that the user has explicitly chosen
class GoogleDriveService {
  static GoogleDriveService? _instance;
  final GoogleAuthService _authService = GoogleAuthService.instance;
  GooglePickerService? _pickerService;

  drive.DriveApi? _driveApi;
  sheets.SheetsApi? _sheetsApi;

  // Note: We don't specify scopes here as GoogleAuthService now handles this centrally

  GoogleDriveService._() {
    // No need to initialize scopes here - GoogleAuthService handles scopes centrally
    // Picker service is lazily initialized to avoid circular dependency
  }

  /// Get GooglePickerService instance lazily to avoid circular dependency
  GooglePickerService get pickerService {
    _pickerService ??= GooglePickerService.instance;
    return _pickerService!;
  }

  static GoogleDriveService get instance {
    _instance ??= GoogleDriveService._();
    return _instance!;
  }

  /// Initialize Drive API client if needed
  Future<drive.DriveApi?> _getDriveApi() async {
    if (_driveApi != null) return _driveApi;

    final client = await _authService.getAuthClient();
    if (client == null) return null;

    _driveApi = drive.DriveApi(client);
    return _driveApi;
  }

  /// Initialize Sheets API client if needed
  Future<sheets.SheetsApi?> _getSheetsApi() async {
    if (_sheetsApi != null) return _sheetsApi;

    final client = await _authService.getAuthClient();
    if (client == null) return null;

    _sheetsApi = sheets.SheetsApi(client);
    return _sheetsApi;
  }

  /// Signs in to Google if not already signed in and sets up Drive API client
  Future<bool> signInAndSetup() async {
    try {
      final success = await _authService.signIn();
      if (!success) return false;

      // Initialize the Drive API
      await _getDriveApi();
      return true;
    } catch (error) {
      Logger.d('Error setting up Google Drive: $error');
      return false;
    }
  }

  /// Sign out current user and clear API instances
  Future<void> signOut() async {
    await _authService.signOut();
    _driveApi = null;
    _sheetsApi = null;
  }

  /// Get file metadata by ID
  Future<drive.File?> getFileInfo(String fileId) async {
    final api = await _getDriveApi();
    if (api == null) return null;

    try {
      return await api.files.get(fileId) as drive.File;
    } catch (e) {
      Logger.d('Error getting file info: $e');
      return null;
    }
  }

  /// Pick a spreadsheet file using the Google Picker API
  /// This works with the restricted drive.file scope
  /// Returns a local file downloaded from Google Drive
  Future<File?> pickSpreadsheetFile(BuildContext context) async {
    try {
      // Make sure we're signed in first
      final signedIn = await _authService.signIn();
      if (!signedIn) {
        if (context.mounted) {
          DialogUtils.showErrorDialog(context,
              message:
                  'Sign-in Failed: Unable to sign in to Google. Please try again.');
        }
        return null;
      }
      if (!context.mounted) {
        Logger.d('Context not mounted - skipping file pick');
        return null;
      }

      // Use the picker service to let the user select a file
      final file = await pickerService.pickGoogleDriveFile(context);
      if (file == null) {
        // User cancelled or error occurred (already handled in picker service)
        return null;
      }

      return file;
    } catch (e) {
      Logger.d('Error picking spreadsheet file: $e');
      if (context.mounted) {
        DialogUtils.showErrorDialog(context,
            message:
                'File Selection Error: An error occurred while selecting the file. Please try again.');
      }
      return null;
    }
  }

  /// Creates a new Google Sheet with the given title
  /// Returns the file ID and name of the created sheet
  Future<Map<String, String>?> createGoogleSheet(
      BuildContext context, String title) async {
    try {
      // Make sure we're signed in and have Sheets API
      final sheetsApi = await _getSheetsApi();
      final driveApi = await _getDriveApi();

      if (sheetsApi == null || driveApi == null) {
        if (context.mounted) {
          DialogUtils.showErrorDialog(context,
              message:
                  'Connection Error: Unable to connect to Google Services. Please check your connection and try again.');
        }
        return null;
      }

      if (!context.mounted) return null;

      return await DialogUtils.executeWithLoadingDialog<Map<String, String>>(
          context, operation: () async {
        // Create a new spreadsheet
        final spreadsheet = sheets.Spreadsheet(
            properties: sheets.SpreadsheetProperties(title: title));
        final createdSpreadsheet =
            await sheetsApi.spreadsheets.create(spreadsheet);

        // Get the spreadsheet ID
        final spreadsheetId = createdSpreadsheet.spreadsheetId;
        if (spreadsheetId == null) {
          throw Exception('Failed to create spreadsheet: No ID returned');
        }

        // Make the file accessible via link
        await driveApi.permissions.create(
          drive.Permission(
              type: 'anyone', role: 'reader', allowFileDiscovery: false),
          spreadsheetId,
        );

        return {
          'id': spreadsheetId,
          'name': title,
        };
      }, loadingMessage: 'Creating new spreadsheet...');
    } catch (e) {
      Logger.d('Error creating spreadsheet: $e');

      if (context.mounted) {
        DialogUtils.showErrorDialog(context,
            message:
                'Error Creating Spreadsheet: Failed to create a new spreadsheet. Please try again later.');
      }
      return null;
    }
  }

  /// Get the web view link for a file
  Future<String?> getWebViewLink(String fileId) async {
    final api = await _getDriveApi();
    if (api == null) return null;

    try {
      final file = await api.files.get(
        fileId,
        $fields: 'webViewLink',
      ) as drive.File;

      return file.webViewLink;
    } catch (e) {
      Logger.d('Error getting web view link: $e');
      return null;
    }
  }

  /// Set a file to be accessible to anyone with the link
  Future<bool> setFilePublicPermission(String fileId) async {
    final api = await _getDriveApi();
    if (api == null) return false;

    try {
      await api.permissions.create(
        drive.Permission(
          type: 'anyone',
          role: 'reader',
          allowFileDiscovery: false,
        ),
        fileId,
      );
      return true;
    } catch (e) {
      Logger.d('Error setting file permissions: $e');
      return false;
    }
  }

  /// Downloads the specified file from Google Drive or exports via public URL for Google Sheets
  /// Downloads a regular (non-Google Sheet) file from Google Drive using the fileId and accessToken
  /// Google Sheet downloads are handled by GoogleSheetsService.downloadGoogleSheet
  Future<File?> downloadFile(String fileId, String fileName) async {
    Logger.d('Downloading file: $fileId, fileName: $fileName');

    try {
      // Regular file download using API and auth
      final accessToken = await _authService.iosAccessToken;
      if (accessToken == null) {
        Logger.d('Failed to get access token');
        return null;
      }
      final authClient = GoogleAuthClient(accessToken);

      try {
        Logger.d('Downloading regular file');
        // For regular files, use the standard download method
        final response = await authClient.get(
          Uri.parse(
              'https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
        );

        if (response.statusCode != 200) {
          Logger.d(
              'Download failed with status ${response.statusCode}: ${response.body}');
          throw Exception(
              'Failed to download file: ${response.statusCode} ${response.body}');
        }

        // Create a temporary file
        final directory = await getTemporaryDirectory();
        String filePath = '${directory.path}/$fileName';

        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        Logger.d('File downloaded successfully to $filePath');
        return file;
      } catch (e) {
        Logger.d('Error downloading file: $e');
        return null;
      } finally {
        authClient.close();
      }
    } catch (e) {
      Logger.d('Error in _downloadFile: $e');
      return null;
    }
  }
}
