import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xceleration/core/services/i_auth_service.dart';
import 'package:xceleration/core/services/i_remote_api_client.dart';
import 'package:xceleration/core/services/remote_api_client.dart';
import 'package:xceleration/core/utils/logger.dart';

export 'i_auth_service.dart';

class AuthService implements IAuthService {
  AuthService({IRemoteApiClient? remoteApi})
      : _remoteApi = remoteApi ?? RemoteApiClient();
  static final AuthService instance = AuthService();

  final IRemoteApiClient _remoteApi;
  SupabaseClient get _client => _remoteApi.client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;
  @override
  String? get currentEmail => _client.auth.currentUser?.email;
  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Permanently delete the currently authenticated user account.
  /// This expects a Supabase Edge Function named 'delete-user' to exist on the backend.
  /// The function should validate the user's auth and perform deletion using service role.
  Future<void> deleteCurrentUserAccount() async {
    await _remoteApi.init();
    if (!_remoteApi.isInitialized) {
      throw Exception('Remote service not configured');
    }
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('Not signed in');
    }
    try {
      final jwt = _client.auth.currentSession?.accessToken;
      if (jwt == null || jwt.isEmpty) {
        throw Exception('Not signed in');
      }
      // Invoke through the configured client so the request goes to the same
      // Supabase project that issued the user's token. (A hardcoded URL for a
      // different project can never validate that token.)
      final resp = await _client.functions.invoke(
        'delete-user',
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (resp.status < 200 || resp.status >= 300) {
        throw Exception('HTTP ${resp.status}: ${resp.data}');
      }
      Logger.d('delete-user function succeeded');
    } catch (e) {
      Logger.e('delete-user function failed: $e');
      rethrow;
    }
  }

  /// Email + Password sign up
  @override
  Future<AuthResponse> signUpWithEmailPassword(
      String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  /// Email + Password sign in
  @override
  Future<AuthResponse> signInWithEmailPassword(
      String email, String password) async {
    return await _client.auth
        .signInWithPassword(email: email, password: password);
  }

  /// Verifies the code emailed after sign-up.
  @override
  Future<AuthResponse> verifyEmailOtp(String email, String token) =>
      _client.auth.verifyOTP(email: email, token: token, type: OtpType.signup);

  /// Verifies the code emailed for a password reset. The session it returns is
  /// what lets [updatePassword] run.
  @override
  Future<AuthResponse> verifyPasswordResetOtp(String email, String token) =>
      _client.auth
          .verifyOTP(email: email, token: token, type: OtpType.recovery);

  /// Sets a new password for the signed-in user.
  @override
  Future<void> updatePassword(String newPassword) =>
      _client.auth.updateUser(UserAttributes(password: newPassword));

  /// Sends the sign-up code again.
  @override
  Future<void> resendEmailConfirmation(String email) =>
      _client.auth.resend(type: OtpType.signup, email: email);

  /// Sends a password reset email. Configure Redirect URLs in Supabase Auth.
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}
