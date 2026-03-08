import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xceleration/core/services/i_remote_api_client.dart';
import 'package:xceleration/core/utils/logger.dart';

class RemoteApiClient implements IRemoteApiClient {
  RemoteApiClient();

  // TODO(refactor): Remove once ProfileService, ParentLinkService, and
  // AuthService are migrated to constructor-injected IRemoteApiClient.
  static final RemoteApiClient instance = RemoteApiClient();

  bool _initialized = false;
  @override
  bool get isInitialized => _initialized;

  @override
  SupabaseClient get client => Supabase.instance.client;

  @override
  Future<void> init() async {
    if (_initialized) return;
    final url = dotenv.env['SUPABASE_URL'];
    final publicKey = dotenv.env['SUPABASE_PUBLISHABLE_KEY'];
    if (url == null || publicKey == null) {
      Logger.d('Supabase env vars not set; skipping init');
      return;
    }
    await Supabase.initialize(url: url, anonKey: publicKey);
    _initialized = true;
  }
}
