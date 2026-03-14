import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/core/services/i_auth_service.dart';
import 'package:xceleration/core/services/i_remote_api_client.dart';
import 'package:xceleration/core/services/parent_link_service.dart';

@GenerateMocks([IRemoteApiClient, IAuthService])
import 'parent_link_service_test.mocks.dart';

void main() {
  late ParentLinkService service;
  late MockIRemoteApiClient mockRemote;
  late MockIAuthService mockAuth;

  setUp(() {
    mockRemote = MockIRemoteApiClient();
    mockAuth = MockIAuthService();
    service = ParentLinkService(remoteApi: mockRemote, auth: mockAuth);
  });

  group('ParentLinkService', () {
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
}
