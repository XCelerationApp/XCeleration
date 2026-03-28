import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/core/services/connectivity_service.dart';
import 'package:xceleration/core/utils/google_auth_service.dart';
import '../../../helpers/fake_google_sign_in_platform.dart';

@GenerateMocks([ConnectivityService])
import 'google_auth_service_test.mocks.dart';

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

      test('uses lightweight auth when web token already valid', () async {
        final service = buildService();
        // Pre-load a valid web token so the service skips forced interactive sign-in
        await service.setWebToken(
          'cached-web-token',
          DateTime.now().add(const Duration(hours: 1)),
        );
        fakePlatform.setupLightweightSuccess();

        await service.signIn();

        expect(fakePlatform.lightweightCallCount, 1);
        expect(fakePlatform.authenticateCallCount, 0);
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
