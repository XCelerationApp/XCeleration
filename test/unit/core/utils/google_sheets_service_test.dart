import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/core/services/connectivity_service.dart';
import 'package:xceleration/core/utils/google_auth_service.dart';
import 'package:xceleration/core/utils/google_drive_service.dart';
import 'package:xceleration/core/utils/google_sheets_service.dart';

@GenerateMocks([ConnectivityService, GoogleAuthService, GoogleDriveService])
import 'google_sheets_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockConnectivityService mockConnectivity;
  late MockGoogleAuthService mockAuthService;
  late MockGoogleDriveService mockDriveService;

  setUp(() {
    mockConnectivity = MockConnectivityService();
    mockAuthService = MockGoogleAuthService();
    mockDriveService = MockGoogleDriveService();
    SharedPreferences.setMockInitialValues({});
  });

  GoogleSheetsService buildService({bool online = true}) {
    when(mockConnectivity.isOnline()).thenAnswer((_) async => online);
    return GoogleSheetsService.forTesting(
      authService: mockAuthService,
      driveService: mockDriveService,
      connectivity: mockConnectivity,
    );
  }

  group('GoogleSheetsService', () {
    group('signIn', () {
      test('delegates to auth service', () async {
        when(mockAuthService.signIn()).thenAnswer((_) async => true);
        final service = buildService();

        final result = await service.signIn();

        expect(result, isTrue);
        verify(mockAuthService.signIn()).called(1);
      });

      test('returns false when auth service signIn fails', () async {
        when(mockAuthService.signIn()).thenAnswer((_) async => false);
        final service = buildService();

        final result = await service.signIn();

        expect(result, isFalse);
      });
    });

    group('createSheet', () {
      test('returns null when offline', () async {
        final service = buildService(online: false);

        final result = await service.createSheet(title: 'Test Sheet');

        expect(result, isNull);
      });

      test('does not call auth service when offline', () async {
        final service = buildService(online: false);

        await service.createSheet(title: 'Test Sheet');

        verifyNever(mockAuthService.getAuthClient());
      });

      test('returns null when auth client is null (online)', () async {
        when(mockAuthService.getAuthClient()).thenAnswer((_) async => null);
        final service = buildService();

        final result = await service.createSheet(title: 'Test Sheet');

        expect(result, isNull);
      });
    });

    group('updateSheet', () {
      test('returns false when offline', () async {
        final service = buildService(online: false);

        final result = await service.updateSheet(
          spreadsheetId: 'sheet-id',
          data: [
            ['a', 'b']
          ],
        );

        expect(result, isFalse);
      });

      test('does not call auth service when offline', () async {
        final service = buildService(online: false);

        await service.updateSheet(
          spreadsheetId: 'sheet-id',
          data: [
            ['a', 'b']
          ],
        );

        verifyNever(mockAuthService.getAuthClient());
      });

      test('returns false when auth client is null (online)', () async {
        when(mockAuthService.getAuthClient()).thenAnswer((_) async => null);
        final service = buildService();

        final result = await service.updateSheet(
          spreadsheetId: 'sheet-id',
          data: [
            ['a', 'b']
          ],
        );

        expect(result, isFalse);
      });
    });

    group('constructSharingUrl', () {
      test('returns correct Google Sheets sharing URL', () {
        final service = buildService();

        final url = service.constructSharingUrl('abc123');

        expect(url,
            'https://docs.google.com/spreadsheets/d/abc123/edit?usp=sharing');
      });
    });

    group('constructCsvExportUrl', () {
      test('returns correct CSV export URL', () {
        final service = buildService();

        final url = service.constructCsvExportUrl('abc123');

        expect(url,
            'https://www.googleapis.com/drive/v3/files/abc123/export?mimeType=text/csv');
      });
    });

    group('getSheetUri', () {
      test('returns fallback URL when drive service returns null', () async {
        when(mockDriveService.getWebViewLink(any))
            .thenAnswer((_) async => null);
        final service = buildService();

        final uri = await service.getSheetUri('abc123');

        expect(uri.toString(),
            'https://docs.google.com/spreadsheets/d/abc123/edit?usp=sharing');
      });

      test('returns drive API URL when available', () async {
        when(mockDriveService.getWebViewLink(any)).thenAnswer(
            (_) async => 'https://docs.google.com/spreadsheets/d/abc123/edit');
        final service = buildService();

        final uri = await service.getSheetUri('abc123');

        expect(uri.toString(),
            'https://docs.google.com/spreadsheets/d/abc123/edit');
      });
    });

    group('downloadGoogleSheet', () {
      test('returns null when offline', () async {
        final service = buildService(online: false);

        final result = await service.downloadGoogleSheet(
          fileId: 'file-id',
          fileName: 'results',
        );

        expect(result, isNull);
      });

      test('does not call auth service signIn when offline', () async {
        final service = buildService(online: false);

        await service.downloadGoogleSheet(
          fileId: 'file-id',
          fileName: 'results',
        );

        verifyNever(mockAuthService.signIn());
      });

      test('returns null when signIn fails (online)', () async {
        when(mockAuthService.signIn()).thenAnswer((_) async => false);
        final service = buildService();

        final result = await service.downloadGoogleSheet(
          fileId: 'file-id',
          fileName: 'results',
        );

        expect(result, isNull);
      });

      test('returns null when access token is null after sign-in', () async {
        when(mockAuthService.signIn()).thenAnswer((_) async => true);
        when(mockAuthService.iosAccessToken).thenAnswer((_) async => null);
        final service = buildService();

        final result = await service.downloadGoogleSheet(
          fileId: 'file-id',
          fileName: 'results',
        );

        expect(result, isNull);
      });
    });
  });
}
