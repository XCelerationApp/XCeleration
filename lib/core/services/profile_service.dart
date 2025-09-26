import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xceleration/core/services/remote_api_client.dart';
import 'package:xceleration/core/services/auth_service.dart';

class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  SupabaseClient get _client => RemoteApiClient.instance.client;

  Future<void> ensureProfileUpsert() async {
    final userId = AuthService.instance.currentUserId;
    final email = AuthService.instance.currentEmail;
    if (userId == null || email == null) return;
    try {
      await _client.from('user_profiles').upsert({
        'user_id': userId,
        'email': email,
      }, onConflict: 'user_id');
    } catch (_) {
      // Table may not exist yet; ignore silently in MVP
    }
  }
}
