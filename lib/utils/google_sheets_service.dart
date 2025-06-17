import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'google_auth_service.dart';
import 'google_drive_service.dart';

/// Service for interacting with Google Sheets API
class GoogleSheetsService {
  static GoogleSheetsService? _instance;
  final GoogleAuthService _authService = GoogleAuthService.instance;
  GoogleDriveService? _driveService;

  // Private constructor for singleton pattern
  GoogleSheetsService._() {
    // GoogleAuthService is already initialized with proper scopes in its constructor
    // We don't immediately initialize GoogleDriveService to avoid circular dependency
  }
  
  /// Get GoogleDriveService instance, lazily initializing it when needed
  /// This breaks the circular dependency between services
  GoogleDriveService get driveService {
    // Only import and initialize when actually needed
    _driveService ??= GoogleDriveService.instance;
    return _driveService!;
  }

  static GoogleSheetsService get instance {
    _instance ??= GoogleSheetsService._();
    return _instance!;
  }

  /// Create a Google Sheet with the given title and data
  /// Uses drive.file scope with GoogleDriveService
  Future<String?> createSheet({
    required BuildContext context,
    required String title,
    required List<List<dynamic>> data,
  }) async {
    try {
      // Check if signed in
      final signedIn = await _authService.signIn();
      if (!signedIn) {
        Logger.d('Failed to sign in');
        return null;
      }
      
      // Get the auth client
      final client = await _authService.getAuthClient();
      if (client == null) {
        Logger.d('Failed to get auth client');
        return null;
      }
      
      // Create a temporary Sheets API client
      final sheetsApi = sheets.SheetsApi(client);

      // Create the spreadsheet
      Logger.d('Creating spreadsheet');
      final spreadsheet = await sheetsApi.spreadsheets.create(
        sheets.Spreadsheet(
          properties: sheets.SpreadsheetProperties(title: title),
        ),
      );
      
      final spreadsheetId = spreadsheet.spreadsheetId;
      Logger.d('Spreadsheet created: $spreadsheetId');
      if (spreadsheetId == null) return null;

      // Set the spreadsheet to be accessible to anyone with the link
      Logger.d('Setting spreadsheet permissions');
      await driveService.setFilePublicPermission(spreadsheetId);

      // Update the spreadsheet with data
      Logger.d('Updating spreadsheet with data');
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
        spreadsheetId,
      );

      return spreadsheetId;
    } catch (e) {
      Logger.d('Error creating spreadsheet: $e');
      return null;
    }
  }
  
  /// Create a Google Sheet and return a Uri that can be used to view or share it
  /// Uses the modern loading dialog system and drive.file scope
  Future<Uri?> createSheetAndGetUri({
    required BuildContext context,
    required String title,
    required List<List<dynamic>> data,
  }) async {
    try {
      // sign in
      if (!await _authService.signIn()) {
        if (context.mounted) {
          DialogUtils.showErrorDialog(
            context, 
            message: 'Error signing in to your Google account - cannot create a spreadsheet'
          );
        }
        return null;
      }
      

      if (!context.mounted) return null;
      
      // Create the sheet with loading dialog
      final spreadsheetId = await DialogUtils.executeWithLoadingDialog<String?>(
        context,
        operation: () async {
          return await createSheet(
            context: context,
            title: title,
            data: data,
          );
        },
        loadingMessage: 'Creating Google Sheet...'
      );
      
      if (spreadsheetId == null) {
        if (context.mounted) {
          DialogUtils.showErrorDialog(
            context,
            message: 'Failed to create Google Sheet'
          );
        }
        return null;
      }
      
      // Try to get the URL via API with loading dialog
      if (!context.mounted) return null;
      
      final uri = await DialogUtils.executeWithLoadingDialog<Uri?>(
        context,
        operation: () async {
          try {
            // First try to get the URL via the Drive API
            final apiUrl = await driveService.getWebViewLink(spreadsheetId);
            if (apiUrl != null) {
              return Uri.parse(apiUrl);
            }
            
            // Fall back to direct URL construction
            final directUrl = constructSharingUrl(spreadsheetId);
            return Uri.parse(directUrl);
          } catch (e) {
            Logger.d('Error getting URL: $e');
            // Fall back to direct URL construction
            final directUrl = constructSharingUrl(spreadsheetId);
            return Uri.parse(directUrl);
          }
        },
        loadingMessage: 'Getting sheet link...'
      );

      Logger.d('Final Sheet URI: $uri');
      return uri;
    } catch (e) {
      Logger.d('Error creating sheet and getting URI: $e');
      if (context.mounted) {
        DialogUtils.showErrorDialog(
          context,
          message: 'Error creating spreadsheet: ${e.toString()}'
        );
      }
      return null;
    }
  }
  
  /// Construct a sharing URL directly from the spreadsheet ID
  String constructSharingUrl(String spreadsheetId) {
    final webViewLink = 'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit?usp=sharing';
    return webViewLink;
  }
  
  /// Construct a download URL for CSV export
  String constructCsvExportUrl(String spreadsheetId) {
    return 'https://www.googleapis.com/drive/v3/files/$spreadsheetId/export?mimeType=text/csv';
  }
  
  /// Download a Google Sheet as a CSV file
  /// 
  /// Tries multiple approaches to download the Google Sheet as a CSV file
  /// Returns a File containing the downloaded CSV content or null if failed
  Future<File?> downloadGoogleSheet({
    required String fileId, 
    required String fileName,
    BuildContext? context,  // Optional context for loading dialog
  }) async {
    Logger.d('Downloading Google Sheet: $fileId');
    
    try {
      // Ensure we're signed in
      if (!await _authService.signIn()) {
        Logger.d('Failed to sign in to download sheet');
        return null;
      }
      
      final accessToken = await _authService.iosAccessToken;
      if (accessToken == null) {
        Logger.d('Failed to get access token');
        return null;
      }
      
      // Google Sheets need to be exported in a specific format, not downloaded directly
      // We'll use the export endpoint to convert to CSV
      final response = await http.get(
        Uri.parse(constructCsvExportUrl(fileId)),
        headers: { 'Authorization': 'Bearer $accessToken' },
      );
      
      if (response.statusCode != 200) {
        Logger.d('Export failed with status ${response.statusCode}: ${response.body}');
        throw Exception('Failed to export file: ${response.statusCode} ${response.body}');
      }
      
      // Save the CSV content to a file
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName.csv');
      await file.writeAsString(response.body);
      
      Logger.d('Google Sheet successfully exported to CSV: ${file.path}');
      return file;
    } catch (e) {
      Logger.d('Error in downloadGoogleSheet: $e');
      return null;
    }
  }
}
