import 'package:xceleration/core/services/i_auth_service.dart';
import 'package:xceleration/core/services/i_remote_api_client.dart';

class ParentLinkService {
  ParentLinkService({
    required IRemoteApiClient remoteApi,
    required IAuthService auth,
  })  : _remoteApi = remoteApi,
        _auth = auth;

  final IRemoteApiClient _remoteApi;
  final IAuthService _auth;

  Future<List<Map<String, dynamic>>> listLinkedCoaches() async {
    final viewerId = _auth.currentUserId;
    if (viewerId == null) return [];
    try {
      final List rows = await _remoteApi.client
          .from('coach_links')
          .select('coach_user_id')
          .eq('viewer_user_id', viewerId);
      return rows.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> listLinkedCoachesWithProfiles() async {
    final links = await listLinkedCoaches();
    if (links.isEmpty) return [];
    final coachIds = links
        .map((e) => e['coach_user_id']?.toString())
        .whereType<String>()
        .toList();
    if (coachIds.isEmpty) return [];
    try {
      // Postgrest filters return a new builder; reassign or the filter is lost
      // and every user's profile is fetched.
      var query = _remoteApi.client
          .from('user_profiles')
          .select('user_id, email, display_name');
      if (coachIds.length == 1) {
        query = query.eq('user_id', coachIds.first);
      } else {
        final orExpr = coachIds.map((id) => 'user_id.eq.$id').join(',');
        query = query.or(orExpr);
      }
      final List profiles = await query;
      final profileMap = {
        for (final p in profiles)
          (p as Map)['user_id'] as String: {
            'email': p['email'],
            'display_name': p['display_name']
          }
      };
      return coachIds
          .map((id) => {
                'coach_user_id': id,
                'email': profileMap[id]?['email'] ?? '',
                'display_name': profileMap[id]?['display_name'] ?? ''
              })
          .toList();
    } catch (_) {
      // Fallback to ids only
      return coachIds.map((id) => {'coach_user_id': id}).toList();
    }
  }

  Future<bool> linkCoachByEmail(String coachEmail) async {
    final viewerId = _auth.currentUserId;
    if (viewerId == null) return false;
    try {
      // user_profiles is only readable for yourself and linked users, so the
      // coach is found through a lookup function that returns just their id.
      final coachId = await _remoteApi.client.rpc<String?>(
        'find_user_id_by_email',
        params: {'p_email': coachEmail},
      );
      if (coachId == null) return false;
      await _remoteApi.client.from('coach_links').upsert({
        'coach_user_id': coachId,
        'viewer_user_id': viewerId,
      }, onConflict: 'coach_user_id,viewer_user_id');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> unlinkCoach(String coachUserId) async {
    final viewerId = _auth.currentUserId;
    if (viewerId == null) return;
    try {
      await _remoteApi.client
          .from('coach_links')
          .delete()
          .match({'coach_user_id': coachUserId, 'viewer_user_id': viewerId});
    } catch (_) {}
  }
}
