import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/core/services/auth_service.dart';
import 'package:xceleration/core/services/connectivity_service.dart';
import 'package:xceleration/core/services/google_service.dart';
import 'package:xceleration/core/services/i_remote_api_client.dart';
import 'package:xceleration/core/services/parent_link_service.dart';
import 'package:xceleration/core/services/profile_service.dart';

import '../../../helpers/fake_google_sign_in_platform.dart';

@GenerateMocks([
  IRemoteApiClient,
  IAuthService,
  ConnectivityService,
])
import 'core_services_test.mocks.dart';

void main() {
  // ===========================================================================
  // AuthService
  // ===========================================================================
  group('AuthService', () {
    late AuthService service;
    late MockIRemoteApiClient mockRemote;

    setUp(() {
      mockRemote = MockIRemoteApiClient();
      service = AuthService(remoteApi: mockRemote);
    });

    group('deleteCurrentUserAccount', () {
      test('throws when remote is not initialized', () async {
        when(mockRemote.init()).thenAnswer((_) async {});
        when(mockRemote.isInitialized).thenReturn(false);

        await expectLater(
          service.deleteCurrentUserAccount(),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Remote service not configured'),
          )),
        );
      });
    });
  });

  // ===========================================================================
  // ProfileService
  // ===========================================================================
  group('ProfileService', () {
    late ProfileService service;
    late MockIRemoteApiClient mockRemote;
    late MockIAuthService mockAuth;

    setUp(() {
      mockRemote = MockIRemoteApiClient();
      mockAuth = MockIAuthService();
      service = ProfileService(remoteApi: mockRemote, auth: mockAuth);
    });

    group('ensureProfileUpsert', () {
      test('returns without calling client when userId is null', () async {
        when(mockAuth.currentUserId).thenReturn(null);
        when(mockAuth.currentEmail).thenReturn('user@example.com');

        await service.ensureProfileUpsert();

        verifyNever(mockRemote.client);
      });

      test('returns without calling client when email is null', () async {
        when(mockAuth.currentUserId).thenReturn('uid-123');
        when(mockAuth.currentEmail).thenReturn(null);

        await service.ensureProfileUpsert();

        verifyNever(mockRemote.client);
      });

      test('swallows exception thrown by remoteApi.client', () async {
        when(mockAuth.currentUserId).thenReturn('uid-123');
        when(mockAuth.currentEmail).thenReturn('user@example.com');
        when(mockRemote.client).thenThrow(Exception('db error'));

        await expectLater(service.ensureProfileUpsert(), completes);
      });
    });
  });

  // ===========================================================================
  // ParentLinkService
  // ===========================================================================
  group('ParentLinkService', () {
    late ParentLinkService service;
    late MockIRemoteApiClient mockRemote;
    late MockIAuthService mockAuth;

    setUp(() {
      mockRemote = MockIRemoteApiClient();
      mockAuth = MockIAuthService();
      service = ParentLinkService(remoteApi: mockRemote, auth: mockAuth);
    });

    group('listLinkedCoaches', () {
      test('returns empty list when userId is null', () async {
        when(mockAuth.currentUserId).thenReturn(null);

        final result = await service.listLinkedCoaches();

        expect(result, isEmpty);
        verifyNever(mockRemote.client);
      });

      test('returns empty list when client throws', () async {
        when(mockAuth.currentUserId).thenReturn('uid-123');
        when(mockRemote.client).thenThrow(Exception('network error'));

        final result = await service.listLinkedCoaches();

        expect(result, isEmpty);
      });
    });

    group('linkCoachByEmail', () {
      test('returns false when userId is null', () async {
        when(mockAuth.currentUserId).thenReturn(null);

        final result = await service.linkCoachByEmail('coach@example.com');

        expect(result, isFalse);
        verifyNever(mockRemote.client);
      });

      test('returns false when client throws', () async {
        when(mockAuth.currentUserId).thenReturn('uid-123');
        when(mockRemote.client).thenThrow(Exception('network error'));

        final result = await service.linkCoachByEmail('coach@example.com');

        expect(result, isFalse);
      });
    });

    group('unlinkCoach', () {
      test('returns normally when userId is null', () async {
        when(mockAuth.currentUserId).thenReturn(null);

        await expectLater(service.unlinkCoach('coach-user-id'), completes);
        verifyNever(mockRemote.client);
      });

      test('swallows exception thrown by client', () async {
        when(mockAuth.currentUserId).thenReturn('uid-123');
        when(mockRemote.client).thenThrow(Exception('network error'));

        await expectLater(service.unlinkCoach('coach-user-id'), completes);
      });
    });
  });

  // ===========================================================================
  // GoogleService
  // ===========================================================================
  group('GoogleService', () {
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

    GoogleService buildService({bool online = true}) {
      when(mockConnectivity.isOnline()).thenAnswer((_) async => online);
      return GoogleService(connectivity: mockConnectivity);
    }

    group('isSignedIn', () {
      test('returns false when no user is set', () {
        final service = buildService();
        expect(service.isSignedIn, isFalse);
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

        expect(fakePlatform.lightweightCallCount, 0);
        expect(fakePlatform.authenticateCallCount, 0);
      });

      test('returns false when authenticate throws', () async {
        // Default fake throws GoogleSignInException(canceled)
        final service = buildService();

        final result = await service.signIn();

        expect(result, isFalse);
      });

      test('returns false when authenticate throws generic exception',
          () async {
        fakePlatform.shouldThrowGenericException = true;
        final service = buildService();

        final result = await service.signIn();

        expect(result, isFalse);
      });

      test('attempts lightweight authentication before interactive sign-in',
          () async {
        fakePlatform.setupLightweightSuccess();
        final service = buildService();

        await service.signIn();

        expect(fakePlatform.lightweightCallCount, 1);
        expect(fakePlatform.authenticateCallCount, 0);
      });

      test('falls back to interactive sign-in when lightweight fails',
          () async {
        fakePlatform.setupSuccessfulSignIn();
        final service = buildService();

        await service.signIn();

        expect(fakePlatform.lightweightCallCount, 1);
        expect(fakePlatform.authenticateCallCount, 1);
      });

      test('isSignedIn returns true after successful sign-in', () async {
        fakePlatform.setupSuccessfulSignIn();
        final service = buildService();

        await service.signIn();

        expect(service.isSignedIn, isTrue);
      });
    });

    group('signOut', () {
      test('calls GoogleSignIn.signOut', () async {
        final service = buildService();

        await service.signOut();

        expect(fakePlatform.signOutCallCount, 1);
      });

      test('isSignedIn returns false after sign-out', () async {
        fakePlatform.setupSuccessfulSignIn();
        final service = buildService();
        await service.signIn();
        expect(service.isSignedIn, isTrue);

        await service.signOut();

        expect(service.isSignedIn, isFalse);
      });

      test('clears stored preferences on sign-out', () async {
        SharedPreferences.setMockInitialValues({
          'google_access_token': 'token',
          'google_token_expiry': 12345,
        });
        final service = buildService();

        await service.signOut();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('google_access_token'), isNull);
        expect(prefs.getInt('google_token_expiry'), isNull);
      });
    });

    group('getFileInfo', () {
      test('returns null when driveApi is null', () async {
        final service = buildService();

        final result = await service.getFileInfo('file-id');

        expect(result, isNull);
      });

      test('returns null when offline (driveApi set via sign-in)', () async {
        final service = buildService(online: false);

        final result = await service.getFileInfo('file-id');

        expect(result, isNull);
      });
    });

    group('downloadFile', () {
      test('returns null when not signed in', () async {
        final service = buildService();

        final result = await service.downloadFile('file-id', 'file.csv');

        expect(result, isNull);
      });

      test('returns null when offline and signed in', () async {
        fakePlatform.setupSuccessfulSignIn();
        final service = buildService();
        await service.signIn();

        // Now go offline
        when(mockConnectivity.isOnline()).thenAnswer((_) async => false);
        final result = await service.downloadFile('file-id', 'file.csv');

        expect(result, isNull);
      });
    });

    group('downloadSheetAsCsv', () {
      test('returns null when not signed in', () async {
        final service = buildService();

        final result =
            await service.downloadSheetAsCsv('spreadsheet-id', 'results');

        expect(result, isNull);
      });

      test('returns null when offline and signed in', () async {
        fakePlatform.setupSuccessfulSignIn();
        final service = buildService();
        await service.signIn();

        // Now go offline
        when(mockConnectivity.isOnline()).thenAnswer((_) async => false);
        final result =
            await service.downloadSheetAsCsv('spreadsheet-id', 'results');

        expect(result, isNull);
      });
    });
  });
}
