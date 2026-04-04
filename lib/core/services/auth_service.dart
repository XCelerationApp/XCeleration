import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/connectivity_service.dart';
import 'package:xceleration/core/services/i_auth_service.dart';
import 'package:xceleration/core/services/i_remote_api_client.dart';
import 'package:xceleration/core/services/remote_api_client.dart';
import 'package:xceleration/core/utils/logger.dart';

export 'i_auth_service.dart';

class AuthService implements IAuthService {
  AuthService({IRemoteApiClient? remoteApi, ConnectivityService? connectivity})
      : _remoteApi = remoteApi ?? RemoteApiClient(),
        _connectivity = connectivity ?? const ConnectivityService();
  static final AuthService instance = AuthService();

  final IRemoteApiClient _remoteApi;
  final ConnectivityService _connectivity;
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
  Future<Result<void>> deleteCurrentUserAccount() async {
    await _remoteApi.init();
    if (!_remoteApi.isInitialized) {
      return Failure(const AppError(
        userMessage: 'Could not delete account. Please try again.',
        originalException: 'Remote service not configured',
      ));
    }
    final online = await _connectivity.isOnline();
    if (!online) {
      return Failure(const AppError(
        userMessage: 'No internet connection. Please check your network and try again.',
        originalException: 'Device is offline',
      ));
    }
    if (currentUserId == null) {
      return Failure(const AppError(
        userMessage: 'Could not delete account. Please sign in and try again.',
        originalException: 'Not signed in',
      ));
    }
    try {
      await _client.functions.invoke('delete-user', body: {});
      Logger.d('delete-user function succeeded');
      return const Success(null);
    } catch (e) {
      Logger.e('delete-user function failed: $e');
      return Failure(AppError(
        userMessage: 'Could not delete account. Please try again.',
        originalException: e,
      ));
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

  /// Sends a password reset email. Configure Redirect URLs in Supabase Auth.
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Verifies the 6-digit OTP sent after email sign-up.
  @override
  Future<AuthResponse> verifyEmailOtp(String email, String token) async {
    return await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.signup,
    );
  }

  /// Verifies the 6-digit OTP sent for password reset.
  @override
  Future<AuthResponse> verifyPasswordResetOtp(String email, String token) async {
    return await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.recovery,
    );
  }

  /// Updates the current user's password. Must be called after [verifyPasswordResetOtp].
  @override
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Resends the email confirmation OTP to the given address.
  @override
  Future<void> resendEmailConfirmation(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email);
  }
}
