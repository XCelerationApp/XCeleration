import 'dart:async';
// import 'dart:convert'; // Unused
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger.dart';
import '../components/dialog_utils.dart';

/// Consolidated Google service that handles authentication, Drive, and Sheets operations
/// This replaces the separate GoogleAuthService, GoogleDriveService, and GoogleSheetsService
class GoogleService {
  static GoogleService? _instance;
  static GoogleService get instance => _instance ??= GoogleService._();

  // Authentication
  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  String? _accessToken;
  DateTime? _tokenExpiry;

  // API clients
  drive.DriveApi? _driveApi;
  sheets.SheetsApi? _sheetsApi;

  // Configuration
  static String get _webClientId =>
      dotenv.env['GOOGLE_WEB_OAUTH_CLIENT_ID'] ?? '';
  static String get _apiKey => dotenv.env['GOOGLE_WEB_API_KEY'] ?? '';

  // State
  bool _initialized = false;

  GoogleService._();

  /// Initialize the Google service
  Future<void> initialize() async {
    if (_initialized) return;

    _googleSignIn = GoogleSignIn(
      scopes: ['https://www.googleapis.com/auth/drive.file'],
      serverClientId: _webClientId,
      forceCodeForRefreshToken: true,
    );

    await _loadStoredAuth();
    _initialized = true;
  }

  /// Sign in to Google
  Future<bool> signIn() async {
    await initialize();

    try {
      // Check if already signed in with valid token
      if (_currentUser != null && _hasValidToken) {
        Logger.d('Already signed in with valid token');
        return true;
      }

      // Try silent sign-in first
      _currentUser = await _googleSignIn!.signInSilently();

      // If silent sign-in fails, try interactive sign-in
      if (_currentUser == null) {
        _currentUser = await _googleSignIn!.signIn();
      }

      if (_currentUser == null) {
        Logger.d('Sign-in cancelled by user');
        return false;
      }

      // Get access token
      final auth = await _currentUser!.authentication;
      _accessToken = auth.accessToken;
      _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));

      // Initialize API clients
      await _initializeApiClients();

      // Store authentication data
      await _storeAuth();

      Logger.d('Google sign-in successful');
      return true;
    } catch (e) {
      Logger.e('Google sign-in failed', error: e);
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    _currentUser = null;
    _accessToken = null;
    _tokenExpiry = null;
    _driveApi = null;
    _sheetsApi = null;

    await _clearStoredAuth();
    Logger.d('Google sign-out successful');
  }

  /// Check if user is signed in with valid token
  bool get isSignedIn => _currentUser != null && _hasValidToken;

  bool get _hasValidToken {
    if (_accessToken == null || _tokenExpiry == null) return false;
    return DateTime.now()
        .isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)));
  }

  /// Initialize API clients
  Future<void> _initializeApiClients() async {
    if (_accessToken == null) return;

    final client = _GoogleAuthClient(_accessToken!);
    _driveApi = drive.DriveApi(client);
    _sheetsApi = sheets.SheetsApi(client);
  }

  /// DRIVE OPERATIONS

  /// Pick a file from Google Drive
  Future<File?> pickDriveFile(BuildContext context) async {
    if (!await signIn()) {
      if (context.mounted) {
        DialogUtils.showErrorDialog(context,
            message: 'Failed to sign in to Google');
      }
      return null;
    }

    // For now, return null as we'd need to implement the picker
    // This would require additional implementation of the Google Picker API
    Logger.d('Drive file picker not yet implemented in consolidated service');
    return null;
  }

  /// Get file metadata
  Future<drive.File?> getFileInfo(String fileId) async {
    if (_driveApi == null) return null;

    try {
      return await _driveApi!.files.get(fileId) as drive.File;
    } catch (e) {
      Logger.e('Error getting file info', error: e);
      return null;
    }
  }

  /// Download a file from Drive
  Future<File?> downloadFile(String fileId, String fileName) async {
    if (!isSignedIn) return null;

    try {
      final response = await http.get(
        Uri.parse(
            'https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode != 200) {
        Logger.e('Download failed with status ${response.statusCode}');
        return null;
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      return file;
    } catch (e) {
      Logger.e('Error downloading file', error: e);
      return null;
    }
  }

  /// SHEETS OPERATIONS

  /// Create a new Google Sheet
  Future<String?> createSheet({
    required BuildContext context,
    required String title,
    required List<List<dynamic>> data,
  }) async {
    if (!await signIn()) {
      if (context.mounted) {
        DialogUtils.showErrorDialog(context,
            message: 'Failed to sign in to Google');
      }
      return null;
    }

    if (!context.mounted) return null;

    return await DialogUtils.executeWithLoadingDialog<String?>(
      context,
      operation: () async {
        // Create spreadsheet
        final spreadsheet = sheets.Spreadsheet(
          properties: sheets.SpreadsheetProperties(title: title),
        );

        final created = await _sheetsApi!.spreadsheets.create(spreadsheet);
        final spreadsheetId = created.spreadsheetId;

        if (spreadsheetId == null) return null;

        // Make it publicly readable
        await _driveApi!.permissions.create(
          drive.Permission(
              type: 'anyone', role: 'reader', allowFileDiscovery: false),
          spreadsheetId,
        );

        // Add data if provided
        if (data.isNotEmpty) {
          await _addDataToSheet(spreadsheetId, data);
        }

        return spreadsheetId;
      },
      loadingMessage: 'Creating Google Sheet...',
    );
  }

  /// Create a sheet and return its URL
  Future<Uri?> createSheetAndGetUri({
    required BuildContext context,
    required String title,
    required List<List<dynamic>> data,
  }) async {
    final spreadsheetId = await createSheet(
      context: context,
      title: title,
      data: data,
    );

    if (spreadsheetId == null) return null;

    return Uri.parse(
        'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit?usp=sharing');
  }

  /// Download a Google Sheet as CSV
  Future<File?> downloadSheetAsCsv(
      String spreadsheetId, String fileName) async {
    if (!isSignedIn) return null;

    try {
      final response = await http.get(
        Uri.parse(
            'https://www.googleapis.com/drive/v3/files/$spreadsheetId/export?mimeType=text/csv'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode != 200) {
        Logger.e('CSV export failed with status ${response.statusCode}');
        return null;
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName.csv');
      await file.writeAsString(response.body);

      return file;
    } catch (e) {
      Logger.e('Error downloading sheet as CSV', error: e);
      return null;
    }
  }

  /// Add data to a sheet
  Future<void> _addDataToSheet(
      String spreadsheetId, List<List<dynamic>> data) async {
    if (_sheetsApi == null) return;

    try {
      final rows = data
          .map((row) => sheets.RowData(
                values: row
                    .map((cell) => sheets.CellData(
                          userEnteredValue: sheets.ExtendedValue(
                              stringValue: cell.toString()),
                        ))
                    .toList(),
              ))
          .toList();

      final request = sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          sheets.Request(
            appendCells: sheets.AppendCellsRequest(
              sheetId: 0,
              fields: 'userEnteredValue',
              rows: rows,
            ),
          ),
        ],
      );

      await _sheetsApi!.spreadsheets.batchUpdate(request, spreadsheetId);
    } catch (e) {
      Logger.e('Error adding data to sheet', error: e);
    }
  }

  /// AUTHENTICATION PERSISTENCE

  /// Load stored authentication data
  Future<void> _loadStoredAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('google_access_token');

      final expiryMillis = prefs.getInt('google_token_expiry');
      if (expiryMillis != null) {
        _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
      }

      if (_hasValidToken) {
        await _initializeApiClients();
      }
    } catch (e) {
      Logger.e('Error loading stored auth', error: e);
    }
  }

  /// Store authentication data
  Future<void> _storeAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_accessToken != null) {
        await prefs.setString('google_access_token', _accessToken!);
      }

      if (_tokenExpiry != null) {
        await prefs.setInt(
            'google_token_expiry', _tokenExpiry!.millisecondsSinceEpoch);
      }
    } catch (e) {
      Logger.e('Error storing auth', error: e);
    }
  }

  /// Clear stored authentication data
  Future<void> _clearStoredAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('google_access_token');
      await prefs.remove('google_token_expiry');
    } catch (e) {
      Logger.e('Error clearing stored auth', error: e);
    }
  }
}

/// HTTP client that adds authorization header
class _GoogleAuthClient extends http.BaseClient {
  final String accessToken;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this.accessToken);

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
