import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xceleration/core/services/remote_api_client.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/constants/app_constants.dart';
import 'package:http/http.dart' as http;

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;
  String? get currentEmail => _client.auth.currentUser?.email;
  bool get isSignedIn => _client.auth.currentSession != null;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Permanently delete the currently authenticated user account.
  /// This expects a Supabase Edge Function named 'delete-user' to exist on the backend.
  /// The function should validate the user's auth and perform deletion using service role.
  Future<void> deleteCurrentUserAccount() async {
    await RemoteApiClient.instance.init();
    if (!RemoteApiClient.instance.isInitialized) {
      throw Exception('Remote service not configured');
    }
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('Not signed in');
    }
    try {
      // Call the deployed Edge Function URL directly
      final jwt = _client.auth.currentSession?.accessToken;
      if (jwt == null || jwt.isEmpty) {
        throw Exception('Not signed in');
      }
      final uri = Uri.parse(AppConstants.deleteUserFunctionUrl);
      final resp = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: '{}',
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception(
            'HTTP ${resp.statusCode}: ${resp.body}');
      }
      Logger.d('delete-user function succeeded');
    } catch (e) {
      Logger.e('delete-user function failed: $e');
      rethrow;
    }
  }

  /// Email + Password sign up
  Future<AuthResponse> signUpWithEmailPassword(
      String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  /// Email + Password sign in
  Future<AuthResponse> signInWithEmailPassword(
      String email, String password) async {
    return await _client.auth
        .signInWithPassword(email: email, password: password);
  }

  /// Sends a password reset email. Configure Redirect URLs in Supabase Auth.
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}
