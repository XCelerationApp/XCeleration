import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/services/remote_api_client.dart';

void main() {
  group('RemoteApiClient', () {
    // -------------------------------------------------------------------------
    group('isInitialized', () {
      test('returns false before init is called', () {
        final client = RemoteApiClient(
          env: {},
          initializer: ({required url, required anonKey}) async {},
        );

        expect(client.isInitialized, isFalse);
      });

      test('returns true after successful init with env vars present', () async {
        final client = RemoteApiClient(
          env: {
            'SUPABASE_URL': 'https://test.supabase.co',
            'SUPABASE_PUBLISHABLE_KEY': 'anon-key',
          },
          initializer: ({required url, required anonKey}) async {},
        );

        await client.init();

        expect(client.isInitialized, isTrue);
      });

      test('remains false after init skipped due to missing env vars', () async {
        final client = RemoteApiClient(
          env: {},
          initializer: ({required url, required anonKey}) async {},
        );

        await client.init();

        expect(client.isInitialized, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    group('init', () {
      test('calls initializer with url and anonKey from env', () async {
        String? capturedUrl;
        String? capturedKey;

        final client = RemoteApiClient(
          env: {
            'SUPABASE_URL': 'https://test.supabase.co',
            'SUPABASE_PUBLISHABLE_KEY': 'anon-key',
          },
          initializer: ({required String url, required String anonKey}) async {
            capturedUrl = url;
            capturedKey = anonKey;
          },
        );

        await client.init();

        expect(capturedUrl, 'https://test.supabase.co');
        expect(capturedKey, 'anon-key');
      });

      test('skips initializer and does not throw when both env vars are absent',
          () async {
        final client = RemoteApiClient(
          env: {},
          initializer: ({required url, required anonKey}) async {
            fail('initializer must not be called when env vars are absent');
          },
        );

        await expectLater(client.init(), completes);
        expect(client.isInitialized, isFalse);
      });

      test('skips initializer when SUPABASE_URL is absent', () async {
        final client = RemoteApiClient(
          env: {'SUPABASE_PUBLISHABLE_KEY': 'anon-key'},
          initializer: ({required url, required anonKey}) async {
            fail('initializer must not be called when SUPABASE_URL is absent');
          },
        );

        await expectLater(client.init(), completes);
        expect(client.isInitialized, isFalse);
      });

      test('skips initializer when SUPABASE_PUBLISHABLE_KEY is absent',
          () async {
        final client = RemoteApiClient(
          env: {'SUPABASE_URL': 'https://test.supabase.co'},
          initializer: ({required url, required anonKey}) async {
            fail(
                'initializer must not be called when SUPABASE_PUBLISHABLE_KEY is absent');
          },
        );

        await expectLater(client.init(), completes);
        expect(client.isInitialized, isFalse);
      });

      test('is idempotent — second call is a no-op', () async {
        int callCount = 0;

        final client = RemoteApiClient(
          env: {
            'SUPABASE_URL': 'https://test.supabase.co',
            'SUPABASE_PUBLISHABLE_KEY': 'anon-key',
          },
          initializer: ({required url, required anonKey}) async {
            callCount++;
          },
        );

        await client.init();
        await client.init();

        expect(callCount, 1);
        expect(client.isInitialized, isTrue);
      });

      test('remains not initialized after first skipped call, then initializes on second call with env vars',
          () async {
        int callCount = 0;

        // First instance: no env vars — skips
        final clientNoEnv = RemoteApiClient(
          env: {},
          initializer: ({required url, required anonKey}) async {
            callCount++;
          },
        );
        await clientNoEnv.init();
        expect(clientNoEnv.isInitialized, isFalse);
        expect(callCount, 0);

        // Second instance: env vars present — initializes
        final clientWithEnv = RemoteApiClient(
          env: {
            'SUPABASE_URL': 'https://test.supabase.co',
            'SUPABASE_PUBLISHABLE_KEY': 'anon-key',
          },
          initializer: ({required url, required anonKey}) async {
            callCount++;
          },
        );
        await clientWithEnv.init();
        expect(clientWithEnv.isInitialized, isTrue);
        expect(callCount, 1);
      });
    });
  });
}
