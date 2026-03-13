import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xceleration/core/services/i_remote_api_client.dart';
import 'package:xceleration/core/utils/logger.dart';

typedef SupabaseInitializer = Future<void> Function({
  required String url,
  required String anonKey,
});

Future<void> _defaultSupabaseInitializer({
  required String url,
  required String anonKey,
}) =>
    Supabase.initialize(url: url, anonKey: anonKey);

class RemoteApiClient implements IRemoteApiClient {
  RemoteApiClient({
    Map<String, String>? env,
    SupabaseInitializer? initializer,
  })  : _env = env ?? dotenv.env,
        _initializer = initializer ?? _defaultSupabaseInitializer;

  // TODO(refactor): Remove once ProfileService, ParentLinkService, and
  // AuthService are migrated to constructor-injected IRemoteApiClient.
  static final RemoteApiClient instance = RemoteApiClient();

  final Map<String, String> _env;
  final SupabaseInitializer _initializer;

  bool _initialized = false;
  @override
  bool get isInitialized => _initialized;

  @override
  SupabaseClient get client => Supabase.instance.client;

  @override
  Future<void> init() async {
    if (_initialized) return;
    final url = _env['SUPABASE_URL'];
    final publicKey = _env['SUPABASE_PUBLISHABLE_KEY'];
    if (url == null || publicKey == null) {
      Logger.d('Supabase env vars not set; skipping init');
      return;
    }
    await _initializer(url: url, anonKey: publicKey);
    _initialized = true;
  }
}
