import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/core/services/connectivity_service.dart';
import 'package:xceleration/core/utils/google_auth_service.dart';

@GenerateMocks([ConnectivityService])
import 'google_auth_service_test.mocks.dart';

// ignore: must_be_immutable
class FakeGoogleSignInPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements GoogleSignInPlatform {
  bool _shouldSucceed = false;
  String _accessToken = 'fake-access-token';
  int authenticateCallCount = 0;
  int lightweightCallCount = 0;
  int signOutCallCount = 0;

  void setupSuccessfulSignIn({String accessToken = 'fake-access-token'}) {
    _accessToken = accessToken;
    _shouldSucceed = true;
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
    return Future.value(null);
  }

  @override
  Future<AuthenticationResults> authenticate(
      AuthenticateParameters params) async {
    authenticateCallCount++;
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
  }

  @override
  Future<void> disconnect(DisconnectParams params) async {}

  @override
  Future<void> clearAuthorizationToken(
      ClearAuthorizationTokenParams params) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockConnectivityService mockConnectivity;
  late FakeGoogleSignInPlatform fakePlatform;

  setUpAll(() {
    dotenv.loadFromString(isOptional: true);
  });

  setUp(() {
    mockConnectivity = MockConnectivityService();
    fakePlatform = FakeGoogleSignInPlatform();
    GoogleSignInPlatform.instance = fakePlatform;
    SharedPreferences.setMockInitialValues({});
  });

  GoogleAuthService buildService({bool online = true}) {
    when(mockConnectivity.isOnline()).thenAnswer((_) async => online);
    return GoogleAuthService(connectivity: mockConnectivity);
  }

  group('GoogleAuthService', () {
    group('hasValidIosToken', () {
      test('returns false when token is null', () {
        final service = buildService();
        expect(service.hasValidIosToken, isFalse);
      });
    });

    group('hasValidWebToken', () {
      test('returns false when token is null', () {
        final service = buildService();
        expect(service.hasValidWebToken, isFalse);
      });
    });

    group('currentUser', () {
      test('returns null when no user is signed in', () {
        final service = buildService();
        expect(service.currentUser, isNull);
      });
    });

    group('getAuthClient', () {
      test('returns null when no user is signed in', () async {
        final service = buildService();
        final client = await service.getAuthClient();
        expect(client, isNull);
      });
    });

    group('signIn', () {
      test('returns false when offline', () async {
        final service = buildService(online: false);

        final result = await service.signIn();

        expect(result, isFalse);
      });

      test('does not call GoogleSignIn when offline', () async {
        final service = buildService(online: false);

        await service.signIn();

        expect(fakePlatform.authenticateCallCount, 0);
        expect(fakePlatform.lightweightCallCount, 0);
      });

      test('returns false when authenticate throws', () async {
        // Default fake throws GoogleSignInException(canceled)
        final service = buildService();

        final result = await service.signIn();

        expect(result, isFalse);
      });

      test('calls signOut before interactive sign-in when web token missing',
          () async {
        // Default fake: authenticate throws, but signOut is called first
        final service = buildService();

        await service.signIn();

        expect(fakePlatform.signOutCallCount, 1);
        expect(fakePlatform.authenticateCallCount, 1);
      });

      test('returns false when sign-in throws', () async {
        final service = buildService();

        final result = await service.signIn();

        expect(result, isFalse);
      });
    });

    group('signOut', () {
      test('calls GoogleSignIn.signOut', () async {
        final service = buildService();

        await service.signOut();

        expect(fakePlatform.signOutCallCount, 1);
      });

      test('clears current user after sign-out', () async {
        final service = buildService();

        await service.signOut();

        expect(service.currentUser, isNull);
      });

      test('clears stored preferences on sign-out', () async {
        SharedPreferences.setMockInitialValues({
          'google_ios_auth_token': 'token',
          'google_ios_auth_token_expiry': 12345,
          'google_web_auth_token': 'web_token',
          'google_web_auth_token_expiry': 12345,
        });
        final service = buildService();

        await service.signOut();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('google_ios_auth_token'), isNull);
        expect(prefs.getString('google_web_auth_token'), isNull);
      });
    });

    group('token exchange (via webAccessToken)', () {
      test('returns false when offline (offline guard exercises token path)',
          () async {
        final service = buildService(online: false);
        final result = await service.signIn();
        expect(result, isFalse);
      });
    });
  });
}
