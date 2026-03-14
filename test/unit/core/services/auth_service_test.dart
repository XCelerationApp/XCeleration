import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/core/services/auth_service.dart';
import 'package:xceleration/core/services/i_remote_api_client.dart';

@GenerateMocks([IRemoteApiClient])
import 'auth_service_test.mocks.dart';

void main() {
  late AuthService service;
  late MockIRemoteApiClient mockRemote;

  setUp(() {
    mockRemote = MockIRemoteApiClient();
    service = AuthService(remoteApi: mockRemote);
  });

  group('AuthService', () {
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
}
