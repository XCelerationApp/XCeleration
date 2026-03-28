import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// ignore: must_be_immutable
class FakeGoogleSignInPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements GoogleSignInPlatform {
  bool _shouldSucceed = false;
  bool _shouldLightweightSucceed = false;
  bool shouldThrowGenericException = false;
  String _accessToken = 'fake-access-token';
  int authenticateCallCount = 0;
  int lightweightCallCount = 0;
  int signOutCallCount = 0;

  void setupSuccessfulSignIn({String accessToken = 'fake-access-token'}) {
    _accessToken = accessToken;
    _shouldSucceed = true;
  }

  void setupLightweightSuccess({String accessToken = 'fake-access-token'}) {
    _accessToken = accessToken;
    _shouldSucceed = true;
    _shouldLightweightSucceed = true;
  }

  static const _fakeUser =
      GoogleSignInUserData(id: 'user-id', email: 'user@example.com');
  static const _fakeTokens = AuthenticationTokenData(idToken: 'id-token');

  @override
  Stream<AuthenticationEvent>? get authenticationEvents => null;

  @override
  Future<void> init(InitParameters params) async {}

  @override
  bool supportsAuthenticate() => true;

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) {
    lightweightCallCount++;
    if (!_shouldLightweightSucceed) return Future.value(null);
    return Future.value(const AuthenticationResults(
      user: _fakeUser,
      authenticationTokens: _fakeTokens,
    ));
  }

  @override
  Future<AuthenticationResults> authenticate(
      AuthenticateParameters params) async {
    authenticateCallCount++;
    if (shouldThrowGenericException) throw Exception('sign-in error');
    if (!_shouldSucceed) {
      throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled);
    }
    return const AuthenticationResults(
      user: _fakeUser,
      authenticationTokens: _fakeTokens,
    );
  }

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async {
    if (!_shouldSucceed) return null;
    return ClientAuthorizationTokenData(accessToken: _accessToken);
  }

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async {
    return null;
  }

  @override
  Future<void> signOut(SignOutParams params) async {
    signOutCallCount++;
    _shouldSucceed = false;
    _shouldLightweightSucceed = false;
  }

  @override
  Future<void> disconnect(DisconnectParams params) async {}

  @override
  Future<void> clearAuthorizationToken(
      ClearAuthorizationTokenParams params) async {}
}
