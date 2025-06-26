import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:xceleration/core/utils/logger.dart';
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

  /// Sign in to Google
  Future<bool> signIn() async {
    return await _authService.signIn();
  }

  /// Create a Google Sheet with the given title.
  /// Returns the spreadsheet ID if successful.
  Future<String?> createSheet({
    required String title,
  }) async {
    try {
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

      return spreadsheetId;
    } catch (e) {
      Logger.d('Error creating spreadsheet: $e');
      return null;
    }
  }

  /// Updates a Google Sheet with the given data
  Future<bool> updateSheet({
    required String spreadsheetId,
    required List<List<dynamic>> data,
  }) async {
    try {
      // Get the auth client
      final client = await _authService.getAuthClient();
      if (client == null) {
        Logger.d('Failed to get auth client for update');
        return false;
      }

      // Create a temporary Sheets API client
      final sheetsApi = sheets.SheetsApi(client);

      // Update the spreadsheet with data
      Logger.d('Updating spreadsheet with data');
      final batchUpdate = sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          sheets.Request(
            updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
              properties: sheets.SheetProperties(
                sheetId: 0,
                title: 'Results',
              ),
              fields: 'title',
            ),
          ),
          sheets.Request(
            appendCells: sheets.AppendCellsRequest(
              sheetId: 0,
              fields: '*',
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

      Logger.d('Spreadsheet updated: $spreadsheetId');
      return true;
    } catch (e) {
      Logger.d('Error updating spreadsheet: $e');
      return false;
    }
  }

  /// Gets the shareable URI for a sheet
  Future<Uri> getSheetUri(String spreadsheetId) async {
    try {
      // First try to get the URL via the Drive API
      final apiUrl = await driveService.getWebViewLink(spreadsheetId);
      if (apiUrl != null) {
        return Uri.parse(apiUrl);
      }
    } catch (e) {
      Logger.d('Error getting web view link: $e');
    }

    Logger.d('No API URL found, falling back to direct URL construction');
    // Fall back to direct URL construction
    final directUrl = constructSharingUrl(spreadsheetId);
    return Uri.parse(directUrl);
  }

  /// Construct a sharing URL directly from the spreadsheet ID
  String constructSharingUrl(String spreadsheetId) {
    final webViewLink =
        'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit?usp=sharing';
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
    BuildContext? context, // Optional context for loading dialog
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
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode != 200) {
        Logger.d(
            'Export failed with status ${response.statusCode}: ${response.body}');
        throw Exception(
            'Failed to export file: ${response.statusCode} ${response.body}');
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
