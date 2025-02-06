// import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
// import 'package:googleapis_auth/googleapis_auth.dart';
// import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;

class GoogleSheetsUtils {
  // TODO: Replace with your Web Client ID from Google Cloud Console
  // Get this from: https://console.cloud.google.com/apis/credentials
  // Note: The clientId should look something like:
  // '123456789-abcdef.apps.googleusercontent.com'
  static const _clientId = '529053126812-cuhlura1vskuup3lg6hpf6iup6mlje6v.apps.googleusercontent.com';
  
  static Future<bool> testSignIn(BuildContext context) async {
    if (!Platform.isIOS) {
      throw UnsupportedError('Google Sign-In is only supported on iOS devices');
    }
    
    try {
      final googleSignIn = GoogleSignIn(
        scopes: [sheets.SheetsApi.spreadsheetsScope],
        clientId: _clientId,
      );
      
      final account = await googleSignIn.signIn();
      if (account == null) {
        print('Sign in cancelled by user');
        return false;
      }

      final auth = await account.authentication;
      final client = GoogleAuthClient(auth.accessToken!);
      final sheetsApi = sheets.SheetsApi(client);
      print(sheetsApi);
      
      return true;
    } catch (e) {
      print('Sign in error: $e');
      return false;
    }
  }

  static Future<sheets.SheetsApi?> _getSheetsApi(BuildContext context) async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: [
          sheets.SheetsApi.spreadsheetsScope,
          drive.DriveApi.driveFileScope,  // Add file scope for sharing
        ],
        clientId: _clientId,
      );
      
      final account = await googleSignIn.signIn();
      if (account == null) return null;

      final auth = await account.authentication;
      final client = GoogleAuthClient(auth.accessToken!);
      
      return sheets.SheetsApi(client);
    } catch (e) {
      print('Sheets API Error: $e');  // Add error logging
      return null;
    }
  }

  static Future<drive.DriveApi?> _getDriveApi(BuildContext context) async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: [
          drive.DriveApi.driveFileScope,  // Use file scope instead of full drive scope
        ],
        clientId: _clientId,
      );
      
      final account = await googleSignIn.signIn();
      if (account == null) return null;

      final auth = await account.authentication;
      final client = GoogleAuthClient(auth.accessToken!);
      
      return drive.DriveApi(client);
    } catch (e) {
      print('Drive API Error: $e');  // Add error logging
      return null;
    }
  }

  static Future<String?> createSpreadsheet(
    BuildContext context, {
    required String title,
    required List<List<dynamic>> data,
  }) async {
    final sheetsApi = await _getSheetsApi(context);
    if (sheetsApi == null) return null;

    try {
      // Create a new spreadsheet
      final spreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(title: title),
      );

      final createdSpreadsheet = await sheetsApi.spreadsheets.create(spreadsheet);
      final spreadsheetId = createdSpreadsheet.spreadsheetId;

      if (spreadsheetId != null) {
        // Update the values in the first sheet
        final range = 'Sheet1!A1';
        final valueRange = sheets.ValueRange(values: data);

        await sheetsApi.spreadsheets.values.update(
          valueRange,
          spreadsheetId,
          range,
          valueInputOption: 'USER_ENTERED',
        );

        // Set the sharing permissions to "anyone with the link can view"
        final driveApi = await _getDriveApi(context);
        if (driveApi != null) {
          try {
            // Create the permission for anyone to view
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
            
            // Get the file to verify sharing settings
            final file = await driveApi.files.get(
              spreadsheetId,
              $fields: 'webViewLink,permissions',
            ) as drive.File;
            
            print('File permissions: ${file.permissions}');  // Debug log
            
            if (file.webViewLink != null) {
              return file.webViewLink;
            }
            return 'https://docs.google.com/spreadsheets/d/$spreadsheetId';
          } catch (e) {
            print('Error setting permissions: $e');
            // Still return the URL even if permission setting fails
            return 'https://docs.google.com/spreadsheets/d/$spreadsheetId';
          }
        }
        return 'https://docs.google.com/spreadsheets/d/$spreadsheetId';
      }
    } catch (e) {
      print('Spreadsheet creation error: $e');  // Add error logging
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
