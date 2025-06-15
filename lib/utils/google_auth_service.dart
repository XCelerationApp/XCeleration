import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  // Retrieve client ID from environment variables
  static String get _clientId => dotenv.env['GOOGLE_IOS_OAUTH_CLIENT_ID'] ?? '';
  
  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  String? _accessToken;
  DateTime? _accessTokenExpiry;
  bool _prefsLoaded = false;
  bool _signInInitialized = false;
  
  // Default scopes for authentication - now using drive.file scope instead of drive.readonly
  final List<String> _defaultScopes = [
    drive.DriveApi.driveFileScope,
  ];
  
  // Keys for shared preferences
  static const String _keyAccessToken = 'google_auth_token';
  static const String _keyTokenExpiry = 'google_auth_token_expiry';
  
  /// Get the singleton instance of GoogleAuthService
  static GoogleAuthService get instance {
    if (_instance == null) {
      _instance = GoogleAuthService._();
      // Start loading preferences in the background but don't block
      _instance!._loadPrefsAsync();
    }
    return _instance!;
  }
  
  GoogleAuthService._() {
    // Don't initialize anything in constructor
    // Will be done lazily when needed
  }
  
  /// Asynchronously load preferences but don't block instance creation
  Future<void> _loadPrefsAsync() async {
    if (!_prefsLoaded) {
      await _loadAuthDataFromPrefs();
      _prefsLoaded = true;
    }
  }

  /// Load authentication data from shared preferences
  Future<void> _loadAuthDataFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load token and expiry
      _accessToken = prefs.getString(_keyAccessToken);
      final expiryMillis = prefs.getInt(_keyTokenExpiry);
      if (expiryMillis != null) {
        _accessTokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
      }
      
      // We don't track user data, only tokens
      
      Logger.d('Loaded auth data from prefs: token=${_accessToken != null}, expiry=${_accessTokenExpiry?.toIso8601String() ?? 'null'}');
    } catch (e) {
      Logger.d('Error loading auth data from prefs: $e');
    }
  }
  
  /// Save authentication data to shared preferences
  Future<void> _saveAuthDataToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save token and expiry
      if (_accessToken != null) {
        await prefs.setString(_keyAccessToken, _accessToken!);
      } else {
        await prefs.remove(_keyAccessToken);
      }
      
      if (_accessTokenExpiry != null) {
        await prefs.setInt(_keyTokenExpiry, _accessTokenExpiry!.millisecondsSinceEpoch);
      } else {
        await prefs.remove(_keyTokenExpiry);
      }
      
      // We don't track user data, only authentication tokens
      
      Logger.d('Saved auth data to prefs');
    } catch (e) {
      Logger.d('Error saving auth data to prefs: $e');
    }
  }
  
  /// Clear all authentication data from shared preferences
  Future<void> _clearAuthDataFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAccessToken);
      await prefs.remove(_keyTokenExpiry);
      Logger.d('Cleared auth data from prefs');
    } catch (e) {
      Logger.d('Error clearing auth data from prefs: $e');
    }
  }

  /// Initialize Google SignIn with the specified scopes
  void _initializeSignIn(List<String> scopes) {
    if (!_signInInitialized) {
      _googleSignIn = GoogleSignIn(
        scopes: scopes,
        clientId: _clientId,
      );
      _signInInitialized = true;
    }
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
    // Ensure prefs are loaded and sign-in is initialized
    await _ensureInitialized();
    
    if (_currentUser == null) return null;
    
    if (hasValidToken) return _accessToken;
    
    try {
      final auth = await _currentUser!.authentication;
      if (auth.accessToken != null) {
        _accessToken = auth.accessToken;
        _accessTokenExpiry = DateTime.now().add(const Duration(minutes: 55));
        
        // Save the updated token to preferences
        await _saveAuthDataToPrefs();
        return _accessToken;
      }
    } catch (e) {
      Logger.d('Error getting access token: $e');
    }
    
    return null;
  }
  
  /// Ensures the service is fully initialized before performing auth operations
  Future<void> _ensureInitialized() async {
    // Load preferences if not already loaded
    if (!_prefsLoaded) {
      await _loadAuthDataFromPrefs();
      _prefsLoaded = true;
    }
    
    // Initialize sign-in if not already initialized
    if (!_signInInitialized) {
      _initializeSignIn(_defaultScopes);
    }
  }
  
  /// Get an authenticated client that can be used with Google APIs
  Future<http.Client?> getAuthClient() async {
    // getAccessToken already ensures initialization
    final token = await getAccessToken();
    if (token == null) return null;
    return GoogleAuthClient(token);
  }

  /// Check if user is signed in without forcing a sign-in attempt
  Future<bool> isSignedIn() async {
    await _ensureInitialized();
    
    if (hasValidToken && _currentUser != null) return true;
    
    try {
      _currentUser = await _googleSignIn!.signInSilently();
      return _currentUser != null;
    } catch (e) {
      Logger.d('Silent sign-in error: $e');
      return false;
    }
  }

  /// Sign in the user - only use when explicitly requested by the user
  /// Tries silent sign-in first before prompting interactive sign-in
  Future<bool> signIn() async {
    await _ensureInitialized();
    
    // If we already have a valid token, no need to sign in again
    if (hasValidToken && _currentUser != null) {
      Logger.d('Already signed in with valid token');
      return true;
    }
    
    // First, try silent sign-in
    try {
      Logger.d('Attempting silent sign-in');
      _currentUser = await _googleSignIn!.signInSilently();
      
      if (_currentUser != null) {
        final auth = await _currentUser!.authentication;
        if (auth.accessToken != null) {
          Logger.d('Silent sign-in successful');
          _accessToken = auth.accessToken;
          _accessTokenExpiry = DateTime.now().add(const Duration(minutes: 55));
          
          // Save all auth data to preferences
          await _saveAuthDataToPrefs();
          
          return true;
        }
      }
      
      // If silent sign-in failed, try interactive sign-in
      Logger.d('Silent sign-in failed, trying interactive sign-in');
      _currentUser = await _googleSignIn!.signIn();
      
      if (_currentUser != null) {
        final auth = await _currentUser!.authentication;
        if (auth.accessToken != null) {
          Logger.d('Interactive sign-in successful');
          _accessToken = auth.accessToken;
          _accessTokenExpiry = DateTime.now().add(const Duration(minutes: 55));
          
          // Save all auth data to preferences
          await _saveAuthDataToPrefs();
          
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
    await _ensureInitialized();
    
    _accessToken = null;
    _accessTokenExpiry = null;
    await _googleSignIn!.signOut();
    _currentUser = null;
    
    // Clear all saved auth data
    await _clearAuthDataFromPrefs();
  }
  
  /// Get a client and account in a single call - mostly for internal use
  Future<(http.Client?, GoogleSignInAccount?)> getAuthClientAndUser(BuildContext context) async {
    await _ensureInitialized();
    
    // First, check if we already have a cached valid token
    if (hasValidToken && _currentUser != null) {
      return (GoogleAuthClient(_accessToken!), _currentUser);
    }
    
    // Try to authenticate the user (first silently, then interactively if needed)
    final success = await signIn();
    
    // Return the client and user if sign-in was successful
    if (success && _accessToken != null) {
      return (GoogleAuthClient(_accessToken!), _currentUser);
    }
    
    // Sign-in failed
    return (null, null);
  }
}
