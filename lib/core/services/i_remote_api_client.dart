import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class IRemoteApiClient {
  SupabaseClient get client;
  bool get isInitialized;
  Future<void> init();
}
