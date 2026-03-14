import 'package:xceleration/core/services/i_auth_service.dart';
import 'package:xceleration/core/services/i_remote_api_client.dart';

class ProfileService {
  ProfileService({
    required IRemoteApiClient remoteApi,
    required IAuthService auth,
  })  : _remoteApi = remoteApi,
        _auth = auth;

  final IRemoteApiClient _remoteApi;
  final IAuthService _auth;

  Future<void> ensureProfileUpsert() async {
    final userId = _auth.currentUserId;
    final email = _auth.currentEmail;
    if (userId == null || email == null) return;
    try {
      await _remoteApi.client.from('user_profiles').upsert({
        'user_id': userId,
        'email': email,
      }, onConflict: 'user_id');
    } catch (_) {
      // Table may not exist yet; ignore silently in MVP
    }
  }
}
