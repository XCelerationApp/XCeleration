import 'dart:io';
import 'package:xceleration/core/utils/logger.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleDriveService {
  static GoogleDriveService? _instance;
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/drive.readonly',
    ],
    clientId: '529053126812-cuhlura1vskuup3lg6hpf6iup6mlje6v.apps.googleusercontent.com',
  );
  
  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;

  GoogleDriveService._();

  static GoogleDriveService get instance {
    _instance ??= GoogleDriveService._();
    return _instance!;
  }

  /// Signs in to Google if not already signed in and sets up Drive API client
  Future<bool> signInAndSetup() async {
    try {
      if (_currentUser == null) {
        _currentUser = await _googleSignIn.signIn();
        if (_currentUser == null) {
          return false; // User canceled the sign-in
        }
      }

      // Get auth headers and setup Drive API
      final headers = await _currentUser!.authHeaders;
      final client = GoogleAuthClient(headers);
      _driveApi = drive.DriveApi(client);
      
      // Save user info to preferences for later use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('google_user_email', _currentUser!.email);
      await prefs.setString('google_user_name', _currentUser!.displayName ?? '');
      
      return true;
    } catch (error) {
      Logger.d('Error signing in to Google: $error');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
    
    // Clear saved user info
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('google_user_email');
    await prefs.remove('google_user_name');
  }

  /// Gets the current signed-in user or tries to sign in silently
  Future<GoogleSignInAccount?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;
    
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        // Setup Drive API
        final headers = await _currentUser!.authHeaders;
        final client = GoogleAuthClient(headers);
        _driveApi = drive.DriveApi(client);
      }
      return _currentUser;
    } catch (e) {
      Logger.d('Error getting current user: $e');
      return null;
    }
  }
  
  /// Get the access token for API usage
  Future<String?> getAccessToken() async {
    if (_currentUser == null) {
      final success = await signInAndSetup();
      if (!success) return null;
    }
    
    try {
      final auth = await _currentUser!.authentication;
      return auth.accessToken;
    } catch (e) {
      Logger.d('Error getting access token: $e');
      return null;
    }
  }
  
  /// Get file metadata by ID
  Future<drive.File?> getFileInfo(String fileId) async {
    if (_driveApi == null) {
      final success = await signInAndSetup();
      if (!success) return null;
    }
    
    try {
      return await _driveApi!.files.get(fileId) as drive.File;
    } catch (e) {
      Logger.d('Error getting file info: $e');
      return null;
    }
  }

  /// Lists spreadsheet files from Google Drive
  Future<List<drive.File>> listSpreadsheetFiles() async {
    if (_driveApi == null) {
      final success = await signInAndSetup();
      if (!success) return [];
    }
    
    try {
      final fileList = await _driveApi!.files.list(
        q: "mimeType='application/vnd.google-apps.spreadsheet' or mimeType='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' or mimeType='text/csv'",
        spaces: 'drive',
        $fields: 'files(id, name, mimeType)',
      );
      
      return fileList.files ?? [];
    } catch (e) {
      Logger.d('Error listing Drive files: $e');
      return [];
    }
  }

  /// Downloads a file from Google Drive by its fileId
  Future<File?> downloadFile(String fileId, String fileName) async {
    if (_driveApi == null) {
      final success = await signInAndSetup();
      if (!success) return null;
    }
    
    try {
      // Get the file metadata to determine appropriate extension
      final fileMetadata = await _driveApi!.files.get(
        fileId,
        $fields: 'mimeType,name',
      ) as drive.File;
      
      final mimeType = fileMetadata.mimeType ?? '';
      String extension = '.unknown';
      
      if (mimeType == 'application/vnd.google-apps.spreadsheet') {
        // Export Google Sheets to Excel format
        final response = await _driveApi!.files.export(
          fileId,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          downloadOptions: drive.DownloadOptions.fullMedia,
        );
        extension = '.xlsx';
        return _saveResponseToFile(response as drive.Media, fileName + extension);
      } else {
        // Download regular files (like .xlsx or .csv)
        final response = await _driveApi!.files.get(
          fileId,
          downloadOptions: drive.DownloadOptions.fullMedia,
        );
        
        if (mimeType.contains('spreadsheet') || mimeType.contains('excel')) {
          extension = '.xlsx';
        } else if (mimeType.contains('csv')) {
          extension = '.csv';
        }
        
        return _saveResponseToFile(response as drive.Media, fileName + extension);
      }
    } catch (e) {
      Logger.d('Error downloading file: $e');
      return null;
    }
  }
  
  Future<File> _saveResponseToFile(drive.Media media, String filename) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    
    final List<int> dataStore = [];
    await for (final data in media.stream) {
      dataStore.addAll(data);
    }
    
    await file.writeAsBytes(dataStore);
    return file;
  }
}

/// Client to authenticate requests using OAuth2 credentials
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
