import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
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
      // Check if we're already signed in or try to sign in
      if (!await _authService.isSignedIn()) {
        if (!await _authService.signIn()) {
          if (context.mounted) {
            DialogUtils.showErrorDialog(
              context, 
              message: 'Please sign in to your Google account to create a spreadsheet'
            );
          }
          return null;
        }
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
    return 'https://docs.google.com/spreadsheets/d/$spreadsheetId/export?format=csv';
  }
  
  /// Download a Google Sheet as a CSV file
  /// 
  /// Tries multiple approaches to download the Google Sheet as a CSV file
  /// Returns a File containing the downloaded CSV content or null if failed
  Future<File?> downloadGoogleSheet({
    required String fileId, 
    required String fileName,
    String? url,  // Optional direct URL to the sheet from picker
    BuildContext? context,  // Optional context for loading dialog
  }) async {
    Logger.d('Downloading Google Sheet: $fileId, URL: $url');
    
    try {
      // Ensure we're signed in
      if (!await _authService.isSignedIn()) {
        if (!await _authService.signIn()) {
          Logger.d('Failed to sign in to download sheet');
          return null;
        }
      }

      final accessToken = await _authService.getAccessToken();
      if (accessToken == null) {
        Logger.d('Failed to get access token');
        return null;
      }
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
        headers: { 'Authorization': 'Bearer $accessToken' },
      );
      
      if (response.statusCode != 200) {
        Logger.d('Download failed with status ${response.statusCode}: ${response.body}');
        throw Exception('Failed to download file: ${response.statusCode} ${response.body}');
      }
      Logger.d('File: ${response.body}');
      return null;
      
      // Operation that does the actual download
      Future<File?> downloadOperation() async {
        // Try multiple approaches in order of preference
        File? file;
        
        // 1. Try using the export API with Google API client (most reliable but requires proper scopes)
        file = await _tryExportWithGoogleApiClient(fileId, fileName);
        if (file != null) return file;
        
        // 2. Try using the export API with direct authenticated HTTP request
        file = await _tryDirectExportApiRequest(fileId, fileName);
        if (file != null) return file;
        
        // 3. Try using direct CSV export URL from sheets URL
        if (url != null) {
          file = await _tryDirectCsvExportFromUrl(url, fileName);
          if (file != null) return file;
        }
        
        // 4. Try using public export URL
        file = await _tryPublicCsvExport(fileId, fileName);
        if (file != null) return file;
        
        // All approaches failed
        Logger.d('All download approaches failed for Google Sheet $fileId');
        return null;
      };
      
      // // Use loading dialog if context is provided, otherwise direct operation
      // if (context != null && context.mounted) {
      //   return await DialogUtils.executeWithLoadingDialog<File?>(
      //     context,
      //     loadingMessage: 'Downloading Google Sheet...',
      //     operation: downloadOperation,
      //   );
      // } else {
      //   return await downloadOperation();
      // }
    } catch (e) {
      Logger.d('Error in downloadGoogleSheet: $e');
      return null;
    }
  }
  
  /// Try to export sheet using Google API client
  Future<File?> _tryExportWithGoogleApiClient(String fileId, String fileName) async {
    Logger.d('Trying to export sheet using Google API client');
    try {
      final client = await _authService.getAuthClient();
      if (client == null) {
        Logger.d('Failed to get auth client for API export');
        return null;
      }
      
      // Use the Drive API directly
      final driveApi = drive.DriveApi(client);
      
      try {
        // First try to get file metadata to check if we can access it
        // and to get alternative download links
        final fileMetadata = await driveApi.files.get(
          fileId,
          $fields: 'id,name,webContentLink,webViewLink',
        ) as drive.File;
        
        Logger.d('Got file metadata: ${fileMetadata.toJson()}');
        
        // Try using webContentLink if available (may work better than export)
        if (fileMetadata.webContentLink != null) {
          Logger.d('Found webContentLink: ${fileMetadata.webContentLink}');
          final downloadUrl = fileMetadata.webContentLink!;
          
          // Try downloading with auth token
          final token = await _authService.getAccessToken();
          final http.Client httpClient = http.Client();
          try {
            final headers = <String, String>{};
            if (token != null) {
              headers['Authorization'] = 'Bearer $token';
            }
            
            final response = await httpClient.get(
              Uri.parse(downloadUrl),
              headers: headers
            );
            
            if (response.statusCode == 200) {
              final directory = await getTemporaryDirectory();
              final outputFileName = fileName.endsWith('.csv') ? fileName : '$fileName.csv';
              final filePath = '${directory.path}/$outputFileName';
              final file = File(filePath);
              await file.writeAsBytes(response.bodyBytes);
              
              Logger.d('File successfully downloaded using webContentLink to $filePath');
              return file;
            } else {
              Logger.d('webContentLink download failed with status ${response.statusCode}');
            }
          } finally {
            httpClient.close();
          }
        }
      } catch (e) {
        Logger.d('Error getting file metadata: $e');
      }
      
      // Fall back to export API
      try {
        // Get the response as a Media object
        final media = await driveApi.files.export(
          fileId, 
          'text/csv',
          downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media;
        
        // Read the media stream
        final List<int> dataStore = [];
        await for (var data in media.stream) {
          dataStore.addAll(data);
        }
        
        if (dataStore.isEmpty) {
          Logger.d('Empty response from API client export');
          return null;
        }
        
        // Save to file
        final directory = await getTemporaryDirectory();
        final outputFileName = fileName.endsWith('.csv') ? fileName : '$fileName.csv';
        final filePath = '${directory.path}/$outputFileName';
        final file = File(filePath);
        await file.writeAsBytes(dataStore);
        
        Logger.d('File successfully downloaded using API client to $filePath');
        return file;
      } catch (e) {
        Logger.d('Error with regular export API: $e');
        return null;
      }
    } catch (e) {
      Logger.d('Error exporting with Google API client: $e');
      return null;
    }
  }
  
  /// Try direct export API request with auth token
  Future<File?> _tryDirectExportApiRequest(String fileId, String fileName) async {
    Logger.d('Trying direct export API request');
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        Logger.d('Failed to get access token for direct export');
        return null;
      }
      
      // Create authenticated client
      final authClient = GoogleAuthClient(token);
      
      try {
        final response = await authClient.get(
          Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId/export?mimeType=text/csv'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        );
        
        if (response.statusCode != 200) {
          Logger.d('Direct export API failed with status ${response.statusCode}');
          return null;
        }
        
        // Create a temporary file with CSV extension
        final directory = await getTemporaryDirectory();
        final outputFileName = fileName.endsWith('.csv') ? fileName : '$fileName.csv';
        final filePath = '${directory.path}/$outputFileName';
        final file = File(filePath);
        
        // Write the content to the file
        await file.writeAsBytes(response.bodyBytes);
        
        Logger.d('File successfully downloaded with direct export API to $filePath');
        return file;
      } finally {
        authClient.close();
      }
    } catch (e) {
      Logger.d('Error with direct export API request: $e');
      return null;
    }
  }
  
  /// Try CSV export directly from the Google Sheets URL
  Future<File?> _tryDirectCsvExportFromUrl(String sheetUrl, String fileName) async {
    Logger.d('Trying direct CSV export from URL: $sheetUrl');
    try {
      // Extract file ID from URL if present
      final idMatch = RegExp(r'/d/([a-zA-Z0-9-_]+)').firstMatch(sheetUrl);
      final fileId = idMatch?.group(1);
      
      if (fileId == null) {
        Logger.d('Could not extract file ID from URL');
        return null;
      }
      
      // Get auth token for authenticated request
      final token = await _authService.getAccessToken();
      
      // Convert edit URL to export URL
      // From: https://docs.google.com/spreadsheets/d/{fileId}/edit...
      // To:   https://docs.google.com/spreadsheets/d/{fileId}/export?format=csv
      final exportUrl = 'https://docs.google.com/spreadsheets/d/$fileId/export?format=csv';
      Logger.d('Generated export URL: $exportUrl');
      
      final client = http.Client();
      try {
        final headers = <String, String>{};
        if (token != null) {
          // Add auth if we have it
          headers['Authorization'] = 'Bearer $token';
        }
        
        final response = await client.get(Uri.parse(exportUrl), headers: headers);
        
        if (response.statusCode != 200) {
          Logger.d('Direct URL export failed with status ${response.statusCode}');
          return null;
        }
        
        // Create a temporary file with CSV extension
        final directory = await getTemporaryDirectory();
        final outputFileName = fileName.endsWith('.csv') ? fileName : '$fileName.csv';
        final filePath = '${directory.path}/$outputFileName';
        final file = File(filePath);
        
        // Write the content to the file
        await file.writeAsBytes(response.bodyBytes);
        
        Logger.d('File successfully downloaded via direct URL export to $filePath');
        return file;
      } finally {
        client.close();
      }
    } catch (e) {
      Logger.d('Error with direct URL export: $e');
      return null;
    }
  }
  
  /// Try public CSV export URL without auth
  Future<File?> _tryPublicCsvExport(String fileId, String fileName) async {
    Logger.d('Trying public CSV export URL');
    try {
      final client = http.Client();
      try {
        final exportUrl = constructCsvExportUrl(fileId);
        Logger.d('Using public export URL: $exportUrl');
        
        final response = await client.get(Uri.parse(exportUrl));
        
        if (response.statusCode != 200) {
          Logger.d('Public export failed with status ${response.statusCode}');
          return null;
        }
        
        // Create a temporary file with CSV extension
        final directory = await getTemporaryDirectory();
        final outputFileName = fileName.endsWith('.csv') ? fileName : '$fileName.csv';
        final filePath = '${directory.path}/$outputFileName';
        final file = File(filePath);
        
        // Write the content to the file
        await file.writeAsBytes(response.bodyBytes);
        
        Logger.d('File successfully downloaded via public export URL to $filePath');
        return file;
      } finally {
        client.close();
      }
    } catch (e) {
      Logger.d('Error using public export URL: $e');
      return null;
    }
  }
}
