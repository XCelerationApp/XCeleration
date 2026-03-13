import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/core/services/google_service.dart';

@GenerateMocks([GoogleSignIn, GoogleSignInAccount, GoogleSignInAuthentication])
import 'google_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGoogleSignIn mockGoogleSignIn;

  setUp(() {
    mockGoogleSignIn = MockGoogleSignIn();
    SharedPreferences.setMockInitialValues({});
  });

  GoogleService buildService({bool online = true}) => GoogleService.forTesting(
        isOnline: () async => online,
        googleSignIn: mockGoogleSignIn,
      );

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

        verifyNever(mockGoogleSignIn.signInSilently());
        verifyNever(mockGoogleSignIn.signIn());
      });

      test('returns false when GoogleSignIn.signIn returns null', () async {
        when(mockGoogleSignIn.signInSilently()).thenAnswer((_) async => null);
        when(mockGoogleSignIn.signIn()).thenAnswer((_) async => null);
        final service = buildService();

        final result = await service.signIn();

        expect(result, isFalse);
      });

      test('returns false when GoogleSignIn throws', () async {
        when(mockGoogleSignIn.signInSilently())
            .thenThrow(Exception('sign-in error'));
        final service = buildService();

        final result = await service.signIn();

        expect(result, isFalse);
      });

      test('attempts silent sign-in before interactive sign-in', () async {
        final mockAccount = MockGoogleSignInAccount();
        final mockAuth = MockGoogleSignInAuthentication();
        when(mockGoogleSignIn.signInSilently())
            .thenAnswer((_) async => mockAccount);
        when(mockAccount.authentication).thenAnswer((_) async => mockAuth);
        when(mockAuth.accessToken).thenReturn('test-token');
        final service = buildService();

        await service.signIn();

        verify(mockGoogleSignIn.signInSilently()).called(1);
        verifyNever(mockGoogleSignIn.signIn());
      });

      test('falls back to interactive sign-in when silent fails', () async {
        when(mockGoogleSignIn.signInSilently()).thenAnswer((_) async => null);
        when(mockGoogleSignIn.signIn()).thenAnswer((_) async => null);
        final service = buildService();

        await service.signIn();

        verify(mockGoogleSignIn.signInSilently()).called(1);
        verify(mockGoogleSignIn.signIn()).called(1);
      });

      test('isSignedIn returns true after successful sign-in', () async {
        final mockAccount = MockGoogleSignInAccount();
        final mockAuth = MockGoogleSignInAuthentication();
        when(mockGoogleSignIn.signInSilently())
            .thenAnswer((_) async => mockAccount);
        when(mockAccount.authentication).thenAnswer((_) async => mockAuth);
        when(mockAuth.accessToken).thenReturn('test-token');
        final service = buildService();

        await service.signIn();

        expect(service.isSignedIn, isTrue);
      });
    });

    group('signOut', () {
      test('calls GoogleSignIn.signOut', () async {
        when(mockGoogleSignIn.signOut()).thenAnswer((_) async => null);
        final service = buildService();

        await service.signOut();

        verify(mockGoogleSignIn.signOut()).called(1);
      });

      test('isSignedIn returns false after sign-out', () async {
        final mockAccount = MockGoogleSignInAccount();
        final mockAuth = MockGoogleSignInAuthentication();
        when(mockGoogleSignIn.signInSilently())
            .thenAnswer((_) async => mockAccount);
        when(mockAccount.authentication).thenAnswer((_) async => mockAuth);
        when(mockAuth.accessToken).thenReturn('test-token');
        when(mockGoogleSignIn.signOut()).thenAnswer((_) async => null);
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
        when(mockGoogleSignIn.signOut()).thenAnswer((_) async => null);
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
        var online = true;
        final mockAccount = MockGoogleSignInAccount();
        final mockAuth = MockGoogleSignInAuthentication();
        when(mockGoogleSignIn.signInSilently())
            .thenAnswer((_) async => mockAccount);
        when(mockAccount.authentication).thenAnswer((_) async => mockAuth);
        when(mockAuth.accessToken).thenReturn('test-token');
        final service = GoogleService.forTesting(
          isOnline: () async => online,
          googleSignIn: mockGoogleSignIn,
        );
        await service.signIn();

        // Now go offline
        online = false;
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
        var online = true;
        final mockAccount = MockGoogleSignInAccount();
        final mockAuth = MockGoogleSignInAuthentication();
        when(mockGoogleSignIn.signInSilently())
            .thenAnswer((_) async => mockAccount);
        when(mockAccount.authentication).thenAnswer((_) async => mockAuth);
        when(mockAuth.accessToken).thenReturn('test-token');
        final service = GoogleService.forTesting(
          isOnline: () async => online,
          googleSignIn: mockGoogleSignIn,
        );
        await service.signIn();

        // Now go offline
        online = false;
        final result =
            await service.downloadSheetAsCsv('spreadsheet-id', 'results');

        expect(result, isNull);
      });
    });
  });
}
