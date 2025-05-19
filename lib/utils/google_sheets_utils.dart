import 'package:flutter/material.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../core/components/dialog_utils.dart';

class GoogleSheetsUtils {
  static const _clientId =
      '529053126812-cuhlura1vskuup3lg6hpf6iup6mlje6v.apps.googleusercontent.com';

  static GoogleSignIn? _googleSignIn;

  static Future<bool> testSignIn(BuildContext context) async {
    debugPrint('testSignIn called');
    try {
      // Initialize GoogleSignIn if not already done
      _googleSignIn ??= GoogleSignIn(
        scopes: [
          sheets.SheetsApi.spreadsheetsScope,
          drive.DriveApi.driveFileScope,
        ],
        clientId: _clientId,
      );
      debugPrint('GoogleSignIn initialized');

      // Try to get existing account first
      debugPrint('Attempting silent sign-in');
      final account = await _googleSignIn!.signInSilently();
      debugPrint(
          'Silent sign-in result: ${account != null ? 'success' : 'failed'}');

      if (account != null) {
        debugPrint('Found existing account');
        return true;
      }

      // If no existing account, try to sign in
      debugPrint('No existing account, attempting regular sign-in');
      final signedInAccount = await _googleSignIn!.signIn();
      debugPrint(
          'Regular sign-in result: ${signedInAccount != null ? 'success' : 'failed'}');

      if (signedInAccount == null) {
        debugPrint('Sign in cancelled by user');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Sign in error: $e');
      return false;
    }
  }

  static Future<sheets.SheetsApi?> _getSheetsApi(BuildContext context) async {
    debugPrint('_getSheetsApi called');
    try {
      _googleSignIn ??= GoogleSignIn(
        scopes: [
          sheets.SheetsApi.spreadsheetsScope,
          drive.DriveApi.driveFileScope,
        ],
        clientId: _clientId,
      );
      debugPrint('GoogleSignIn instance: $_googleSignIn');

      // Try to get existing account first
      debugPrint('Attempting silent sign-in for SheetsApi');
      final account = await _googleSignIn!.signInSilently();
      debugPrint(
          'Silent sign-in result: ${account != null ? 'success' : 'failed'}');

      if (account != null) {
        debugPrint('Found existing account');
        final auth = await account.authentication;
        debugPrint(
            'Authentication result: ${auth.accessToken != null ? 'success' : 'failed'}');

        if (auth.accessToken != null) {
          debugPrint('Access token found');
          final client = GoogleAuthClient(auth.accessToken!);
          debugPrint('Creating SheetsApi client');
          return sheets.SheetsApi(client);
        }
      }

      // If no existing account or invalid credentials, sign in again
      debugPrint('No valid credentials, attempting regular sign-in');
      final signedInAccount = await _googleSignIn!.signIn();
      debugPrint(
          'Regular sign-in result: ${signedInAccount != null ? 'success' : 'failed'}');

      if (signedInAccount == null) {
        debugPrint('Sign in cancelled by user');
        return null;
      }

      final auth = await signedInAccount.authentication;
      debugPrint(
          'Authentication result: ${auth.accessToken != null ? 'success' : 'failed'}');

      if (auth.accessToken == null) {
        debugPrint('Failed to get authentication');
        return null;
      }

      final client = GoogleAuthClient(auth.accessToken!);
      debugPrint('Creating SheetsApi client');
      return sheets.SheetsApi(client);
    } catch (e) {
      debugPrint('Sheets API Error: $e');
      return null;
    }
  }

  static Future<drive.DriveApi?> _getDriveApi(BuildContext context) async {
    debugPrint('_getDriveApi called');
    try {
      _googleSignIn ??= GoogleSignIn(
        scopes: [
          sheets.SheetsApi.spreadsheetsScope,
          drive.DriveApi.driveFileScope,
        ],
        clientId: _clientId,
      );
      debugPrint('GoogleSignIn instance: $_googleSignIn');

      // Try to get existing account first
      debugPrint('Attempting silent sign-in for DriveApi');
      final account = await _googleSignIn!.signInSilently();
      debugPrint(
          'Silent sign-in result: ${account != null ? 'success' : 'failed'}');

      if (account != null) {
        debugPrint('Found existing account');
        final auth = await account.authentication;
        debugPrint(
            'Authentication result: ${auth.accessToken != null ? 'success' : 'failed'}');

        if (auth.accessToken != null) {
          debugPrint('Access token found');
          final client = GoogleAuthClient(auth.accessToken!);
          debugPrint('Creating DriveApi client');
          return drive.DriveApi(client);
        }
      }

      // If no existing account or invalid credentials, sign in again
      debugPrint('No valid credentials, attempting regular sign-in');
      final signedInAccount = await _googleSignIn!.signIn();
      debugPrint(
          'Regular sign-in result: ${signedInAccount != null ? 'success' : 'failed'}');

      if (signedInAccount == null) {
        debugPrint('Sign in cancelled by user');
        return null;
      }

      final auth = await signedInAccount.authentication;
      debugPrint(
          'Authentication result: ${auth.accessToken != null ? 'success' : 'failed'}');

      if (auth.accessToken == null) {
        debugPrint('Failed to get authentication');
        return null;
      }

      final client = GoogleAuthClient(auth.accessToken!);
      debugPrint('Creating DriveApi client');
      return drive.DriveApi(client);
    } catch (e) {
      debugPrint('Drive API Error: $e');
      return null;
    }
  }

  static Future<String?> createSpreadsheet(
    BuildContext context, {
    required String title,
    required List<List<dynamic>> data,
  }) async {
    debugPrint('createSpreadsheet called');
    try {
      // First check if we're signed in
      debugPrint('Checking if signed in');
      if (!await testSignIn(context)) {
        debugPrint('Not signed in');
        if (!context.mounted) return null;
        DialogUtils.showErrorDialog(
          context,
          message:
              'Please sign in to your Google account to export to Google Sheets',
        );
        return null;
      }

      debugPrint('Getting SheetsApi');
      
      // Check if context is still mounted before using it
      if (!context.mounted) return null;
      
      final sheetsApi = await _getSheetsApi(context);
      debugPrint(
          'SheetsApi result: ${sheetsApi != null ? 'success' : 'failed'}');

      if (sheetsApi == null) {
        debugPrint('Failed to get SheetsApi');
        if (!context.mounted) return null;
        DialogUtils.showErrorDialog(
          context,
          message: 'Failed to connect to Google Sheets',
        );
        return null;
      }

      // Create the spreadsheet
      debugPrint('Creating spreadsheet');
      final spreadsheet = await sheetsApi.spreadsheets.create(
        sheets.Spreadsheet(
          properties: sheets.SpreadsheetProperties(title: title),
        ),
      );
      debugPrint('Spreadsheet created: ${spreadsheet.spreadsheetId}');

      // Set the spreadsheet to be accessible to anyone with the link
      debugPrint('Setting spreadsheet permissions');
      
      // Check if context is still mounted before using it
      if (!context.mounted) return null;
      
      final driveApi = await _getDriveApi(context);
      
      // Check if context is still mounted after getting the Drive API
      if (!context.mounted) return null;
      
      if (driveApi != null && spreadsheet.spreadsheetId != null) {
        try {
          await driveApi.permissions.create(
            drive.Permission(
              type: 'anyone',
              role: 'reader',
              allowFileDiscovery: false,
            ),
            spreadsheet.spreadsheetId!,
          );
          debugPrint('Permissions set successfully');
        } catch (e) {
          debugPrint('Error setting permissions: $e');
          // Don't fail the entire operation if permissions can't be set
        }
      }

      // Update the spreadsheet with data
      debugPrint('Updating spreadsheet with data');
      final batchUpdate = sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          sheets.Request(
            addSheet: sheets.AddSheetRequest(
              properties: sheets.SheetProperties(
                title: 'Results',
              ),
            ),
          ),
          sheets.Request(
            appendCells: sheets.AppendCellsRequest(
              sheetId: 0,
              fields: 'userEnteredValue',
              rows: data
                  .map((row) => sheets.RowData(values: [
                        for (var cell in row)
                          sheets.CellData(
                            userEnteredValue: sheets.ExtendedValue(
                              stringValue: cell.toString(),
                            ),
                          ),
                      ]))
                  .toList(),
            ),
          ),
        ],
      );

      await sheetsApi.spreadsheets.batchUpdate(
        batchUpdate,
        spreadsheet.spreadsheetId!,
      );

      // Get the sharing URL
      debugPrint('Getting sharing URL');
      final driveFile = await driveApi?.files.get(
        spreadsheet.spreadsheetId!,
        $fields: 'webViewLink',
        supportsAllDrives: true,
      );

      if (driveFile == null) {
        debugPrint('Failed to get drive file');
        if (!context.mounted) return null;
        DialogUtils.showErrorDialog(
          context,
          message: 'Failed to get sharing URL',
        );
        return null;
      }

      final webViewLink = (driveFile as drive.File).webViewLink;
      if (webViewLink == null) {
        debugPrint('Failed to get webViewLink');
        if (!context.mounted) return null;
        DialogUtils.showErrorDialog(
          context,
          message: 'Failed to get sharing URL',
        );
        return null;
      }

      return webViewLink;
    } catch (e) {
      debugPrint('Error creating spreadsheet: $e');
      if (!context.mounted) return null;
      DialogUtils.showErrorDialog(
        context,
        message: 'Failed to create Google Sheet',
      );
      return null;
    }
  }
}

class GoogleAuthClient extends http.BaseClient {
  final String accessToken;
  final http.Client _client = http.Client();

  GoogleAuthClient(this.accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $accessToken';
    debugPrint(
        'Sending request with token: ${accessToken.substring(0, 10)}...');
    return _client.send(request);
  }
}
