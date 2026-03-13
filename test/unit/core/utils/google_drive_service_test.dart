import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/core/services/connectivity_service.dart';
import 'package:xceleration/core/utils/google_auth_service.dart';
import 'package:xceleration/core/utils/google_drive_service.dart';

@GenerateMocks([ConnectivityService, GoogleAuthService])
import 'google_drive_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockConnectivityService mockConnectivity;
  late MockGoogleAuthService mockAuthService;

  setUp(() {
    mockConnectivity = MockConnectivityService();
    mockAuthService = MockGoogleAuthService();
    SharedPreferences.setMockInitialValues({});
  });

  GoogleDriveService buildService({bool online = true}) {
    when(mockConnectivity.isOnline()).thenAnswer((_) async => online);
    return GoogleDriveService(
      authService: mockAuthService,
      connectivity: mockConnectivity,
    );
  }

  group('GoogleDriveService', () {
    group('signInAndSetup', () {
      test('returns false when auth service signIn fails', () async {
        when(mockAuthService.signIn()).thenAnswer((_) async => false);
        final service = buildService();

        final result = await service.signInAndSetup();

        expect(result, isFalse);
      });

      test('returns true when auth service signIn succeeds', () async {
        when(mockAuthService.signIn()).thenAnswer((_) async => true);
        when(mockAuthService.getAuthClient()).thenAnswer((_) async => null);
        final service = buildService();

        final result = await service.signInAndSetup();

        expect(result, isTrue);
      });

      test('returns false when signIn throws', () async {
        when(mockAuthService.signIn()).thenThrow(Exception('auth error'));
        final service = buildService();

        final result = await service.signInAndSetup();

        expect(result, isFalse);
      });
    });

    group('signOut', () {
      test('delegates to auth service signOut', () async {
        when(mockAuthService.signOut()).thenAnswer((_) async {});
        final service = buildService();

        await service.signOut();

        verify(mockAuthService.signOut()).called(1);
      });
    });

    group('getFileInfo', () {
      test('returns null when offline', () async {
        final service = buildService(online: false);

        final result = await service.getFileInfo('file-id');

        expect(result, isNull);
      });

      test('does not call auth service when offline', () async {
        final service = buildService(online: false);

        await service.getFileInfo('file-id');

        verifyNever(mockAuthService.getAuthClient());
      });

      test('returns null when auth client is null (online)', () async {
        when(mockAuthService.getAuthClient()).thenAnswer((_) async => null);
        final service = buildService();

        final result = await service.getFileInfo('file-id');

        expect(result, isNull);
      });
    });

    group('getWebViewLink', () {
      test('returns null when offline', () async {
        final service = buildService(online: false);

        final result = await service.getWebViewLink('file-id');

        expect(result, isNull);
      });

      test('returns null when auth client is null (online)', () async {
        when(mockAuthService.getAuthClient()).thenAnswer((_) async => null);
        final service = buildService();

        final result = await service.getWebViewLink('file-id');

        expect(result, isNull);
      });
    });

    group('setFilePublicPermission', () {
      test('returns false when offline', () async {
        final service = buildService(online: false);

        final result = await service.setFilePublicPermission('file-id');

        expect(result, isFalse);
      });

      test('does not call auth service when offline', () async {
        final service = buildService(online: false);

        await service.setFilePublicPermission('file-id');

        verifyNever(mockAuthService.getAuthClient());
      });

      test('returns false when auth client is null (online)', () async {
        when(mockAuthService.getAuthClient()).thenAnswer((_) async => null);
        final service = buildService();

        final result = await service.setFilePublicPermission('file-id');

        expect(result, isFalse);
      });
    });

    group('downloadFile', () {
      test('returns null when offline', () async {
        when(mockAuthService.iosAccessToken).thenAnswer((_) async => null);
        final service = buildService(online: false);

        final result = await service.downloadFile('file-id', 'file.csv');

        expect(result, isNull);
      });

      test('does not call auth service for token when offline', () async {
        final service = buildService(online: false);

        await service.downloadFile('file-id', 'file.csv');

        verifyNever(mockAuthService.iosAccessToken);
      });

      test('returns null when access token is null (online)', () async {
        when(mockAuthService.iosAccessToken).thenAnswer((_) async => null);
        final service = buildService();

        final result = await service.downloadFile('file-id', 'file.csv');

        expect(result, isNull);
      });
    });
  });
}
