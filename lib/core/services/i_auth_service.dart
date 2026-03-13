import 'package:gotrue/gotrue.dart';

abstract interface class IAuthService {
  String? get currentUserId;
  String? get currentEmail;
  bool get isSignedIn;

  Future<AuthResponse> signInWithEmailPassword(String email, String password);
  Future<AuthResponse> signUpWithEmailPassword(String email, String password);
  Future<void> sendPasswordResetEmail(String email);
}
