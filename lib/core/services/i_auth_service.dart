abstract interface class IAuthService {
  String? get currentUserId;
  String? get currentEmail;
  bool get isSignedIn;
}
