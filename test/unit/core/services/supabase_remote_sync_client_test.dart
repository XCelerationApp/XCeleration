import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xceleration/core/services/i_remote_api_client.dart';
import 'package:xceleration/core/services/supabase_remote_sync_client.dart';

@GenerateMocks([IRemoteApiClient])
import 'supabase_remote_sync_client_test.mocks.dart';

void main() {
  late List<http.Request> requests;
  late SupabaseRemoteSyncClient syncClient;

  setUp(() {
    requests = [];
    final httpClient = MockClient((request) async {
      requests.add(request);
      return http.Response('[]', 200,
          request: request, headers: {'content-type': 'application/json'});
    });
    final supabase = SupabaseClient(
      'https://test.supabase.co',
      'anon-key',
      httpClient: httpClient,
    );
    final remote = MockIRemoteApiClient();
    when(remote.client).thenReturn(supabase);
    syncClient = SupabaseRemoteSyncClient(remote: remote);
  });

  Map<String, List<String>> sentParams() =>
      requests.single.url.queryParametersAll;

  group('SupabaseRemoteSyncClient', () {
    group('fetchTableRows', () {
      test('asks only for the given owner\'s rows', () async {
        await syncClient.fetchTableRows('runners', 'user-1');

        expect(sentParams()['owner_user_id'], ['eq.user-1']);
        expect(sentParams().containsKey('or'), isFalse);
      });

      test('only requests rows updated after the cursor', () async {
        await syncClient.fetchTableRows('runners', 'user-1',
            cursor: '2026-09-01T00:00:00.000Z');

        expect(sentParams()['updated_at'], ['gt.2026-09-01T00:00:00.000Z']);
      });

      test('omits the cursor filter when there is no cursor', () async {
        await syncClient.fetchTableRows('runners', 'user-1');

        expect(sentParams().containsKey('updated_at'), isFalse);
      });

      test('orders by updated_at and caps the page at 1000 rows', () async {
        await syncClient.fetchTableRows('runners', 'user-1');

        expect(sentParams()['order'], ['updated_at.asc.nullslast']);
        expect(sentParams()['limit'], ['1000']);
      });
    });
  });
}
