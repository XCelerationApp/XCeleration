import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/auth_service.dart';
import 'package:xceleration/core/services/connectivity_service.dart';
import 'package:xceleration/core/services/i_remote_api_client.dart';

@GenerateMocks([IRemoteApiClient, ConnectivityService])
import 'auth_service_test.mocks.dart';

void main() {
  late AuthService service;
  late MockIRemoteApiClient mockRemote;
  late MockConnectivityService mockConnectivity;

  setUp(() {
    mockRemote = MockIRemoteApiClient();
    mockConnectivity = MockConnectivityService();
    service = AuthService(remoteApi: mockRemote, connectivity: mockConnectivity);
  });

  group('AuthService', () {
    group('deleteCurrentUserAccount', () {
      test('returns Failure when remote is not initialized', () async {
        when(mockRemote.init()).thenAnswer((_) async {});
        when(mockRemote.isInitialized).thenReturn(false);

        final result = await service.deleteCurrentUserAccount();

        expect(result, isA<Failure<void>>());
        expect(
          (result as Failure<void>).error.userMessage,
          contains('Could not delete account'),
        );
      });

      test('returns Failure with offline message when device has no connection',
          () async {
        when(mockRemote.init()).thenAnswer((_) async {});
        when(mockRemote.isInitialized).thenReturn(true);
        when(mockConnectivity.isOnline()).thenAnswer((_) async => false);

        final result = await service.deleteCurrentUserAccount();

        expect(result, isA<Failure<void>>());
        expect(
          (result as Failure<void>).error.userMessage,
          contains('No internet connection'),
        );
      });
    });
  });
}
