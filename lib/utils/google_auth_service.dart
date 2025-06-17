import 'dart:async';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/core/utils/logger.dart';
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
  static String get _iosClientId => dotenv.env['GOOGLE_IOS_OAUTH_CLIENT_ID'] ?? '';
  static String get _webClientId => dotenv.env['GOOGLE_WEB_OAUTH_CLIENT_ID'] ?? '';
  static String get _webClientSecret => dotenv.env['GOOGLE_WEB_OAUTH_CLIENT_SECRET'] ?? '';
  
  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  String? _iosAccessToken;
  String? _webAccessToken;
  DateTime? _iosAccessTokenExpiry;
  DateTime? _webAccessTokenExpiry;
  bool _prefsLoaded = false;
  bool _signInInitialized = false;
  
  // Keys for shared preferences
  static const String _keyIosAccessToken = 'google_ios_auth_token';
  static const String _keyIosTokenExpiry = 'google_ios_auth_token_expiry';
  static const String _keyWebAccessToken = 'google_web_auth_token';
  static const String _keyWebTokenExpiry = 'google_web_auth_token_expiry';
  
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
      _iosAccessToken = prefs.getString(_keyIosAccessToken);
      final expiryMillis = prefs.getInt(_keyIosTokenExpiry);
      if (expiryMillis != null) {
        _iosAccessTokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
      }
      
      _webAccessToken = prefs.getString(_keyWebAccessToken);
      final webExpiryMillis = prefs.getInt(_keyWebTokenExpiry);
      if (webExpiryMillis != null) {
        _webAccessTokenExpiry = DateTime.fromMillisecondsSinceEpoch(webExpiryMillis);
      }
      
      Logger.d('Loaded auth data from prefs: token=${_iosAccessToken != null}, expiry=${_iosAccessTokenExpiry?.toIso8601String() ?? 'null'}');
      Logger.d('Loaded auth data from prefs: token=${_webAccessToken != null}, expiry=${_webAccessTokenExpiry?.toIso8601String() ?? 'null'}');
    } catch (e) {
      Logger.d('Error loading auth data from prefs: $e');
    }
  }
  
  /// Save authentication data to shared preferences
  Future<void> _saveAuthDataToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save token and expiry
      if (_iosAccessToken != null) {
        await prefs.setString(_keyIosAccessToken, _iosAccessToken!);
      } else {
        await prefs.remove(_keyIosAccessToken);
      }
      if (_iosAccessTokenExpiry != null) {
        await prefs.setInt(_keyIosTokenExpiry, _iosAccessTokenExpiry!.millisecondsSinceEpoch);
      } else {
        await prefs.remove(_keyIosTokenExpiry);
      }

      if (_webAccessToken != null) {
        await prefs.setString(_keyWebAccessToken, _webAccessToken!);
      } else {
        await prefs.remove(_keyWebAccessToken);
      }
      if (_webAccessTokenExpiry != null) {
        await prefs.setInt(_keyWebTokenExpiry, _webAccessTokenExpiry!.millisecondsSinceEpoch);
      } else {
        await prefs.remove(_keyWebTokenExpiry);
      }
      
      Logger.d('Saved auth data to prefs');
    } catch (e) {
      Logger.d('Error saving auth data to prefs: $e');
    }
  }
  
  /// Clear all authentication data from shared preferences
  Future<void> _clearAuthDataFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIosAccessToken);
      await prefs.remove(_keyIosTokenExpiry);
      await prefs.remove(_keyWebAccessToken);
      await prefs.remove(_keyWebTokenExpiry);
      Logger.d('Cleared auth data from prefs');
    } catch (e) {
      Logger.d('Error clearing auth data from prefs: $e');
    }
  }

  /// Initialize Google Sign In
  void _initGoogleSignIn() {
    _googleSignIn ??= GoogleSignIn(
      scopes: [
        'https://www.googleapis.com/auth/drive.file',
      ],
      serverClientId: _webClientId,
      forceCodeForRefreshToken: true, // This forces the auth code to be included
    );
  }

  /// Check if the user is already authenticated with a valid ios token
  bool get hasValidIosToken {
    if (_iosAccessToken == null || _iosAccessTokenExpiry == null) return false;
    // Add 5-minute buffer before token expiry
    return DateTime.now().isBefore(_iosAccessTokenExpiry!.subtract(const Duration(minutes: 5)));
  }

  /// Check if the user is already authenticated with a valid web token
  bool get hasValidWebToken {
    if (_webAccessToken == null || _webAccessTokenExpiry == null) return false;
    // Add 5-minute buffer before token expiry
    return DateTime.now().isBefore(_webAccessTokenExpiry!.subtract(const Duration(minutes: 5)));
  }
  
  /// Get the current signed-in user
  GoogleSignInAccount? get currentUser => _currentUser;
  
  /// Get or refresh the ios access token if we have a signed-in user
  Future<String?> get iosAccessToken async {
    // Ensure prefs are loaded and sign-in is initialized
    await _ensureInitialized();
    
    if (_currentUser == null) return null;
    
    if (hasValidIosToken) return _iosAccessToken;
    
    try {
      final auth = await _currentUser!.authentication;
      if (auth.accessToken != null) {
        _iosAccessToken = auth.accessToken;
        _iosAccessTokenExpiry = DateTime.now().add(const Duration(minutes: 55));
        
        // Save the updated token to preferences
        await _saveAuthDataToPrefs();
        return _iosAccessToken;
      } else {
        Logger.d('Failed to get iOS token - no access token');
        return null;
      }
    } catch (e) {
      Logger.d('Error getting iOS access token: $e');
    }
    
    return null;
  }

  /// Get or refresh the web access token if we have a signed-in user
  Future<String?> get webAccessToken async {
    // Ensure prefs are loaded and sign-in is initialized
    await _ensureInitialized();
    
    if (_currentUser == null) return null;
    
    if (hasValidWebToken) return _webAccessToken;
    
  try {
      final serverAuthCode = _currentUser!.serverAuthCode;
      if (serverAuthCode != null) {
        Logger.d('Exchanging server auth code for access token');
        _webAccessToken = await _exchangeServerAuthCodeForAccessToken(serverAuthCode);
        _webAccessTokenExpiry = DateTime.now().add(const Duration(minutes: 55));
        
        // Save the updated token to preferences
        await _saveAuthDataToPrefs();
        return _webAccessToken;
      } else {
        Logger.d('Failed to get Web token - no server auth code');
        return null;
      }
    } catch (e) {
      Logger.d('Error getting web access token: $e');
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
      _initGoogleSignIn();
      _signInInitialized = true;
    }
  }
  
  /// Get an authenticated client that can be used with Google APIs
  Future<http.Client?> getAuthClient() async {
    // getAccessToken already ensures initialization
    final token = await iosAccessToken;
    if (token == null) return null;
    return GoogleAuthClient(token);
  }

  Future<String?> _exchangeServerAuthCodeForAccessToken(String authCode) async {
    Logger.d('Exchanging auth code for token with client ID: $_webClientId');
    
    // For OAuth token exchange from a mobile app using Google Sign-In's serverAuthCode, 
    final response = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'code': authCode,
        'client_id': _webClientId,
        'client_secret': _webClientSecret,
        // 'redirect_uri': 'com.googleusercontent.apps.$_iosClientId:/oauth/callback',
        'grant_type': 'authorization_code',
      },
    );

    if (response.statusCode == 200) {
      final responseJson = jsonDecode(response.body);
      return responseJson['access_token'] as String?;
    } else {
      Logger.d('Token exchange failed: ${response.body}');
      return null;
    }
  }

  /// Sign in the user - only use when explicitly requested by the user
  /// Tries silent sign-in first before prompting interactive sign-in
  Future<bool> signIn() async {
    try {
      await _ensureInitialized();
      // Check if we already have valid tokens
      if (_currentUser != null && hasValidIosToken && hasValidWebToken) {
        Logger.d('Already signed in with valid iOS and Web tokens');
        return true;
      }
      // If we need a web token but don't have a valid one, force interactive sign-in
      if (!hasValidWebToken) {
        Logger.d('Need web token, forcing interactive sign-in');
        await _googleSignIn!.signOut();
        _currentUser = await _googleSignIn!.signIn();
      } else {
        if (_currentUser == null) {
          // Try silent sign-in first
          Logger.d('Attempting silent sign-in');
          _currentUser = await _googleSignIn!.signInSilently();
          
          if (_currentUser == null) {
            Logger.d('Silent sign-in failed, trying interactive sign-in');
            _currentUser = await _googleSignIn!.signIn();
          }
        }
      }
      if (currentUser == null) {
        Logger.d('Failed to sign in');
        return false;
      }
      _iosAccessToken = await iosAccessToken;
      
      if (!hasValidIosToken) {
        Logger.d('Failed to get iOS token');
        return false;
      }
      _webAccessToken = await webAccessToken;
      if (!hasValidWebToken) {
        Logger.d('Failed to get Web token');
        return false;
      }
      Logger.d('Sign in and token collection successful');

      // Save all auth data to preferences
      await _saveAuthDataToPrefs();
      
      return true;
    } catch (e) {
      Logger.d('Sign in error: $e');
      return false;
    }
  }
  
  /// Sign out the current user
  Future<void> signOut() async {
    await _ensureInitialized();
    
    _iosAccessToken = null;
    _iosAccessTokenExpiry = null;
    _webAccessToken = null;
    _webAccessTokenExpiry = null;
    await _googleSignIn!.signOut();
    _currentUser = null;
    
    // Clear all saved auth data
    await _clearAuthDataFromPrefs();
  }
}
