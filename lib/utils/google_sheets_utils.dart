import 'package:flutter/material.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../core/components/dialog_utils.dart';

class GoogleSheetsUtils {
  static const _clientId = '529053126812-cuhlura1vskuup3lg6hpf6iup6mlje6v.apps.googleusercontent.com';
  
  static Future<bool> testSignIn(BuildContext context) async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: [sheets.SheetsApi.spreadsheetsScope],
        clientId: _clientId,
      );
      
      final account = await googleSignIn.signIn();
      if (account == null) {
        debugPrint('Sign in cancelled by user');
        return false;
      }

      final auth = await account.authentication;
      if (auth.accessToken == null) {
        debugPrint('Failed to get authentication');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Sign in error: $e');
      return false;
    }
  }

  static Future<sheets.SheetsApi?> _getSheetsApi(BuildContext context) async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: [
          sheets.SheetsApi.spreadsheetsScope,
          drive.DriveApi.driveFileScope,
        ],
        clientId: _clientId,
      );
      
      final account = await googleSignIn.signIn();
      if (account == null) {
        debugPrint('Sign in cancelled by user');
        return null;
      }

      final auth = await account.authentication;
      if (auth.accessToken == null) {
        debugPrint('Failed to get authentication');
        return null;
      }

      final client = GoogleAuthClient(auth.accessToken!);
      return sheets.SheetsApi(client);
    } catch (e) {
      debugPrint('Sheets API Error: $e');
      return null;
    }
  }

  static Future<drive.DriveApi?> _getDriveApi(BuildContext context) async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: [
          drive.DriveApi.driveFileScope,
        ],
        clientId: _clientId,
      );
      
      final account = await googleSignIn.signIn();
      if (account == null) {
        debugPrint('Sign in cancelled by user');
        return null;
      }

      final auth = await account.authentication;
      if (auth.accessToken == null) {
        debugPrint('Failed to get authentication');
        return null;
      }

      final client = GoogleAuthClient(auth.accessToken!);
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
    try {
      // First check if we can sign in
      if (!await testSignIn(context)) {
        if (!context.mounted) return null;
        DialogUtils.showErrorDialog(
          context,
          message: 'Please sign in to your Google account to export to Google Sheets',
        );
        return null;
      }

      final sheetsApi = await _getSheetsApi(context);
      if (sheetsApi == null) {
        if (!context.mounted) return null;
        DialogUtils.showErrorDialog(
          context,
          message: 'Failed to connect to Google Sheets',
        );
        return null;
      }

      // Create a new spreadsheet
      final spreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(
          title: title,
          locale: 'en_US',
          timeZone: 'America/New_York',
        ),
      );

      final createdSpreadsheet = await sheetsApi.spreadsheets.create(spreadsheet);
      final spreadsheetId = createdSpreadsheet.spreadsheetId;

      if (spreadsheetId != null) {
        // Update the values in the first sheet
        final range = 'Sheet1!A1';
        
        // Convert dynamic data to proper values for ValueRange
        final List<List<dynamic>> formattedData = data.map((row) {
          return row.map((value) {
            if (value is String) return value;
            if (value is num) return value.toString();
            if (value == null) return '';
            return value.toString();
          }).toList();
        }).toList();

        final valueRange = sheets.ValueRange(values: formattedData);

        try {
          await sheetsApi.spreadsheets.values.update(
            valueRange,
            spreadsheetId,
            range,
            valueInputOption: 'USER_ENTERED',
          );
        } catch (e) {
          debugPrint('Error updating values: $e');
          if (!context.mounted) return null;
          DialogUtils.showErrorDialog(
            context,
            message: 'Failed to update spreadsheet values. Please try again.',
          );
          return null;
        }

        // Set the sharing permissions to 'anyone with the link can view'
        final driveApi = await _getDriveApi(context);
        if (driveApi != null) {
          try {
            final permission = drive.Permission(
              type: 'anyone',
              role: 'reader',
              allowFileDiscovery: false,
            );
            
            await driveApi.permissions.create(
              permission,
              spreadsheetId,
              supportsAllDrives: true,
              supportsTeamDrives: true,
            );
          } catch (e) {
            debugPrint('Error setting permissions: $e');
          }
        }

        return 'https://docs.google.com/spreadsheets/d/$spreadsheetId';
      }
    } catch (e) {
      debugPrint('Spreadsheet creation error: $e');
      if (!context.mounted) return null;
      DialogUtils.showErrorDialog(
        context,
        message: 'Failed to create Google Sheet. Please try again.',
      );
      return null;
    }
    return null;
  }
}

class GoogleAuthClient extends http.BaseClient {
  final String accessToken;
  final http.Client _client = http.Client();

  GoogleAuthClient(this.accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $accessToken';
    return _client.send(request);
  }
}
