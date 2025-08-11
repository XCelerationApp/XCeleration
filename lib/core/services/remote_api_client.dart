import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xceleration/core/utils/logger.dart';

class RemoteApiClient {
  RemoteApiClient._();
  static final RemoteApiClient instance = RemoteApiClient._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  SupabaseClient get client => Supabase.instance.client;

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
