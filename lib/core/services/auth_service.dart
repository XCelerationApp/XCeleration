import 'package:supabase_flutter/supabase_flutter.dart';

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
