import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/core/services/connectivity_service.dart';
import 'package:xceleration/core/services/google_service.dart';
import '../../../helpers/fake_google_sign_in_platform.dart';

@GenerateMocks([ConnectivityService])
import 'google_service_test.mocks.dart';

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

  GoogleService buildService({bool online = true}) {
    when(mockConnectivity.isOnline()).thenAnswer((_) async => online);
    return GoogleService(connectivity: mockConnectivity);
  }

  group('GoogleService', () {
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
