import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/core/services/i_auth_service.dart';
import 'package:xceleration/core/services/i_remote_api_client.dart';
import 'package:xceleration/core/services/profile_service.dart';

@GenerateMocks([IRemoteApiClient, IAuthService])
import 'profile_service_test.mocks.dart';

void main() {
  late ProfileService service;
  late MockIRemoteApiClient mockRemote;
  late MockIAuthService mockAuth;

  setUp(() {
    mockRemote = MockIRemoteApiClient();
    mockAuth = MockIAuthService();
    service = ProfileService(remoteApi: mockRemote, auth: mockAuth);
  });

  group('ProfileService', () {
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
}
