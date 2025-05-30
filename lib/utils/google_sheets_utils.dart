import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:xceleration/core/components/dialog_utils.dart';

class GoogleSheetsUtils {
  static const _clientId =
      '529053126812-cuhlura1vskuup3lg6hpf6iup6mlje6v.apps.googleusercontent.com';

  // Static instances to be reused across the app
  static GoogleSignIn? _googleSignIn;
  static GoogleSignInAccount? _currentUser;
  static String? _cachedAccessToken;
  static DateTime? _tokenExpiry;
  
  // Initialize Google Sign In with required scopes
  static GoogleSignIn get _signIn {
    _googleSignIn ??= GoogleSignIn(
      scopes: [
        sheets.SheetsApi.spreadsheetsScope,
        drive.DriveApi.driveFileScope,
      ],
      clientId: _clientId,
    );
    return _googleSignIn!;
  }

  /// Check if the user is already authenticated with a valid token
  static bool get _hasValidToken {
    if (_cachedAccessToken == null || _tokenExpiry == null) return false;
    // Add 5-minute buffer before token expiry
    return DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)));
  }

  /// Get an authenticated client with minimal sign-in prompts
  /// Only prompts for sign-in when absolutely necessary
  static Future<(http.Client?, GoogleSignInAccount?)> _getAuthClient(BuildContext context) async {
    // 1. First, check if we already have a cached valid token
    if (_hasValidToken && _currentUser != null) {
      return (GoogleAuthClient(_cachedAccessToken!), _currentUser);
    }

    // 2. Try to get the current signed-in user silently (no UI)
    _currentUser ??= await _signIn.signInSilently();
    
    // 3. If we have a user, get a fresh token
    if (_currentUser != null) {
      try {
        final auth = await _currentUser!.authentication;
        if (auth.accessToken != null) {
          // Cache the token and set an approximate expiry (1 hour is typical)
          _cachedAccessToken = auth.accessToken;
          _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
          return (GoogleAuthClient(_cachedAccessToken!), _currentUser);
        }
      } catch (e) {
        // Token refresh failed, will try interactive sign-in
        _currentUser = null;
      }
    }

    // 4. Only prompt for interactive sign-in if necessary
    try {
      _currentUser = await _signIn.signIn();
      if (_currentUser != null) {
        final auth = await _currentUser!.authentication;
        if (auth.accessToken != null) {
          _cachedAccessToken = auth.accessToken;
          _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
          return (GoogleAuthClient(_cachedAccessToken!), _currentUser);
        }
      }
    } catch (e) {
      Logger.d('Sign-in error: $e');
    }

    return (null, null);
  }

  /// Get the Sheets API client - will only prompt for sign-in if necessary
  static Future<sheets.SheetsApi?> _getSheetsApi(BuildContext context) async {
    final (client, _) = await _getAuthClient(context);
    return client != null ? sheets.SheetsApi(client) : null;
  }

  /// Get the Drive API client - will only prompt for sign-in if necessary
  static Future<drive.DriveApi?> _getDriveApi(BuildContext context) async {
    final (client, _) = await _getAuthClient(context);
    return client != null ? drive.DriveApi(client) : null;
  }

  /// Check if the user is signed in without forcing a sign-in attempt
  static Future<bool> isSignedIn() async {
    if (_hasValidToken && _currentUser != null) return true;
    _currentUser = await _signIn.signInSilently();
    return _currentUser != null;
  }

  /// Sign in the user - only use this when explicitly requested by the user
  static Future<bool> signIn() async {
    try {
      _currentUser = await _signIn.signIn();
      if (_currentUser != null) {
        final auth = await _currentUser!.authentication;
        if (auth.accessToken != null) {
          _cachedAccessToken = auth.accessToken;
          _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
          return true;
        }
      }
      return false;
    } catch (e) {
      Logger.d('Sign in error: $e');
      return false;
    }
  }

  /// Sign out the current user
  static Future<void> signOut() async {
    _cachedAccessToken = null;
    _tokenExpiry = null;
    _currentUser = null;
    await _signIn.signOut();
  }

  /// Create a Google Sheet and return a Uri that can be used to view or share it
  /// This is the recommended method for external components to use
  static Future<Uri?> createSheetAndGetUri({
    required BuildContext context,
    required String title,
    required List<List<dynamic>> data,
  }) async {
    try {
      // First check if we're already signed in
      if (!await isSignedIn()) {
        // Try explicit sign-in once if not already signed in
        if (!await signIn()) {
          if (!context.mounted) return null;
          // Show error dialog
          DialogUtils.showErrorDialog(context, message: 'Please sign in to your Google account to access Google Sheets');
          return null;
        }
      }

      if (!context.mounted) throw Exception('Context is not mounted');
      
      // Create the sheet
      final spreadsheetId = await createSheet(
        context: context,
        title: title,
        data: data,
      );
      
      if (spreadsheetId == null) {
        throw Exception('Failed to create Google Sheet');
      }
      
      // Try to get the URL via API first, with a 5 second timeout
      Uri? uri;
      try {
        // Create a completer to handle the timeout logic
        final completer = Completer<Uri?>();
        
        if (!context.mounted) throw Exception('Context is not mounted');

        // Start the API request
        _getUrlFromApi(context, spreadsheetId).then((apiUrl) {
          if (!completer.isCompleted) {
            completer.complete(apiUrl != null ? Uri.parse(apiUrl) : null);
          }
        }).catchError((error) {
          if (!completer.isCompleted) {
            Logger.d('Error getting URL from API: $error');
            completer.complete(null);
          }
        });
        
        // Set a timeout for the API request
        Future.delayed(const Duration(seconds: 5), () {
          if (!completer.isCompleted) {
            Logger.d('API URL request timed out, using direct URL construction');
            final directUrl = constructSharingUrl(spreadsheetId);
            completer.complete(Uri.parse(directUrl));
          }
        });
        
        // Wait for either the API response or the timeout
        uri = await completer.future;
      } catch (e) {
        Logger.d('Error in URL retrieval process: $e');
        // Fall back to direct construction if there was an error
        final directUrl = constructSharingUrl(spreadsheetId);
        uri = Uri.parse(directUrl);
      }

      Logger.d('Final Sheet URI: $uri');
      return uri;
    } catch (e) {
      Logger.d('Error creating sheet and getting URI: $e');
      rethrow;
    }
  }

  /// Internal method to create a Google Sheet with the given title and data
  /// This method handles the actual API calls and returns the spreadsheet ID
  static Future<String?> createSheet({
    required BuildContext context,
    required String title,
    required List<List<dynamic>> data,
  }) async {
    try {
      // Get the Sheets API client
      final sheetsApi = await _getSheetsApi(context);
      if (sheetsApi == null) return null;

      // Create the spreadsheet
      Logger.d('Creating spreadsheet');
      final spreadsheet = await sheetsApi.spreadsheets.create(
        sheets.Spreadsheet(
          properties: sheets.SpreadsheetProperties(title: title),
        ),
      );
      Logger.d('Spreadsheet created: ${spreadsheet.spreadsheetId}');

      // Set the spreadsheet to be accessible to anyone with the link
      Logger.d('Setting spreadsheet permissions');
      
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
          Logger.d('Permissions set successfully');
        } catch (e) {
          Logger.d('Error setting permissions: $e');
          // Don't fail the entire operation if permissions can't be set
        }
      }

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
        spreadsheet.spreadsheetId!,
      );

      return spreadsheet.spreadsheetId;
    } catch (e) {
      Logger.d('Error creating spreadsheet: $e');
      return null;
    }
  }
  
  /// Get the URL for a spreadsheet from the Drive API
  static Future<String?> _getUrlFromApi(BuildContext context, String spreadsheetId) async {
    final driveApi = await _getDriveApi(context);
    if (driveApi == null) return null;
    
    try {
      Logger.d('Getting file metadata from Drive API');
      final file = await driveApi.files.get(
        spreadsheetId,
        $fields: 'webViewLink',
      ) as drive.File;
      
      if (file.webViewLink != null) {
        Logger.d('Retrieved web view link: ${file.webViewLink}');
        return file.webViewLink;
      } else {
        Logger.d('No web view link found in file metadata');
        return null;
      }
    } catch (e) {
      Logger.d('Error getting file metadata: $e');
      return null;
    }
  }
  
  /// Construct a sharing URL directly from the spreadsheet ID
  static String constructSharingUrl(String spreadsheetId) {
    Logger.d('Constructing sharing URL directly');
    final webViewLink = 'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit?usp=sharing';
    Logger.d('Direct sharing URL: $webViewLink');
    return webViewLink;
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

  @override
  void close() {
    _client.close();
    super.close();
  }
}
