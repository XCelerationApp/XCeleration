import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// Authentication client for Google APIs
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

/// Service for handling Google authentication
class GoogleAuthService {
  static GoogleAuthService? _instance;
  static const String _clientId = '529053126812-cuhlura1vskuup3lg6hpf6iup6mlje6v.apps.googleusercontent.com';
  
  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  String? _accessToken;
  DateTime? _accessTokenExpiry;
  
  // Default scopes for authentication - now using drive.file scope instead of drive.readonly
  final List<String> _defaultScopes = [
    drive.DriveApi.driveFileScope,
  ];
  
  /// Get the singleton instance of GoogleAuthService
  static GoogleAuthService get instance => _instance ??= GoogleAuthService._();

  GoogleAuthService._() {
    // Initialize with default scopes
    _initializeSignIn(_defaultScopes);
  }

  /// Initialize Google SignIn with the specified scopes
  void _initializeSignIn(List<String> scopes) {
    _googleSignIn = GoogleSignIn(
      scopes: scopes,
      clientId: _clientId,
    );
  }

  /// Check if the user is already authenticated with a valid token
  bool get hasValidToken {
    if (_accessToken == null || _accessTokenExpiry == null) return false;
    // Add 5-minute buffer before token expiry
    return DateTime.now().isBefore(_accessTokenExpiry!.subtract(const Duration(minutes: 5)));
  }
  
  /// Get the current signed-in user
  GoogleSignInAccount? get currentUser => _currentUser;
  
  /// Get or refresh the access token if we have a signed-in user
  Future<String?> getAccessToken() async {
    if (_currentUser == null) return null;
    
    if (hasValidToken) return _accessToken;
    
    try {
      final auth = await _currentUser!.authentication;
      if (auth.accessToken != null) {
        _accessToken = auth.accessToken;
        _accessTokenExpiry = DateTime.now().add(const Duration(minutes: 55));
        return _accessToken;
      }
    } catch (e) {
      Logger.d('Error getting access token: $e');
    }
    
    return null;
  }
  
  /// Get an authenticated client that can be used with Google APIs
  Future<http.Client?> getAuthClient() async {
    final token = await getAccessToken();
    if (token == null) return null;
    return GoogleAuthClient(token);
  }

  /// Check if user is signed in without forcing a sign-in attempt
  Future<bool> isSignedIn() async {
    if (hasValidToken && _currentUser != null) return true;
    
    if (_googleSignIn == null) {
      Logger.d('GoogleSignIn not initialized');
      return false;
    }
    
    _currentUser = await _googleSignIn!.signInSilently();
    return _currentUser != null;
  }

  /// Sign in the user - only use when explicitly requested by the user
  Future<bool> signIn() async {
    if (_googleSignIn == null) {
      Logger.d('GoogleSignIn not initialized');
      return false;
    }
    
    try {
      _currentUser = await _googleSignIn!.signIn();
      if (_currentUser != null) {
        final auth = await _currentUser!.authentication;
        if (auth.accessToken != null) {
          _accessToken = auth.accessToken;
          _accessTokenExpiry = DateTime.now().add(const Duration(minutes: 55));
          
          // Save user info to preferences for later use
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('google_user_email', _currentUser!.email);
          await prefs.setString('google_user_name', _currentUser!.displayName ?? '');
          
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
  Future<void> signOut() async {
    if (_googleSignIn == null) return;
    
    _accessToken = null;
    _accessTokenExpiry = null;
    await _googleSignIn!.signOut();
    _currentUser = null;
    
    // Clear saved user info
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('google_user_email');
    await prefs.remove('google_user_name');
  }
  
  /// Get a client and account in a single call - mostly for internal use
  Future<(http.Client?, GoogleSignInAccount?)> getAuthClientAndUser(BuildContext context) async {
    // First, check if we already have a cached valid token
    if (hasValidToken && _currentUser != null) {
      return (GoogleAuthClient(_accessToken!), _currentUser);
    }

    // Try to get the current signed-in user silently (no UI)
    if (_googleSignIn != null) {
      _currentUser ??= await _googleSignIn!.signInSilently();
    }
    
    // If we have a user, get a fresh token
    if (_currentUser != null) {
      try {
        final auth = await _currentUser!.authentication;
        if (auth.accessToken != null) {
          // Cache the token and set an approximate expiry (1 hour is typical)
          _accessToken = auth.accessToken;
          _accessTokenExpiry = DateTime.now().add(const Duration(minutes: 55));
          return (GoogleAuthClient(_accessToken!), _currentUser);
        }
      } catch (e) {
        // Token refresh failed, will try interactive sign-in
        _currentUser = null;
      }
    }

    // Only prompt for interactive sign-in if necessary
    if (_googleSignIn != null) {
      try {
        _currentUser = await _googleSignIn!.signIn();
        if (_currentUser != null) {
          final auth = await _currentUser!.authentication;
          if (auth.accessToken != null) {
            _accessToken = auth.accessToken;
            _accessTokenExpiry = DateTime.now().add(const Duration(minutes: 55));
            return (GoogleAuthClient(_accessToken!), _currentUser);
          }
        }
      } catch (e) {
        Logger.d('Sign-in error: $e');
      }
    }

    return (null, null);
  }
}
