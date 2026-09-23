import 'package:gotrue/gotrue.dart';

abstract interface class IAuthService {
  String? get currentUserId;
  String? get currentEmail;
  bool get isSignedIn;

  Future<AuthResponse> signInWithEmailPassword(String email, String password);
  Future<AuthResponse> signUpWithEmailPassword(String email, String password);
  Future<void> sendPasswordResetEmail(String email);

  /// Verifies the code emailed after sign-up.
  Future<AuthResponse> verifyEmailOtp(String email, String token);

  /// Verifies the code emailed for a password reset. The session it returns
  /// is what lets [updatePassword] run.
  Future<AuthResponse> verifyPasswordResetOtp(String email, String token);

  /// Sets a new password for the signed-in user. Only meaningful after
  /// [verifyPasswordResetOtp].
  Future<void> updatePassword(String newPassword);

  /// Sends the sign-up code again.
  Future<void> resendEmailConfirmation(String email);
}
