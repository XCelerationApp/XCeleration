import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xceleration/core/services/remote_api_client.dart';
import 'package:xceleration/core/services/auth_service.dart';

class ParentLinkService {
  ParentLinkService._();
  static final ParentLinkService instance = ParentLinkService._();

  SupabaseClient get _client => RemoteApiClient.instance.client;

  Future<List<Map<String, dynamic>>> listLinkedCoaches() async {
    final viewerId = AuthService.instance.currentUserId;
    if (viewerId == null) return [];
    try {
      final List rows = await _client
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
      final query =
          _client.from('user_profiles').select('user_id, email, display_name');
      if (coachIds.length == 1) {
        query.eq('user_id', coachIds.first);
      } else {
        final orExpr = coachIds.map((id) => 'user_id.eq.$id').join(',');
        query.or(orExpr);
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
    final viewerId = AuthService.instance.currentUserId;
    if (viewerId == null) return false;
    try {
      final List profiles = await _client
          .from('user_profiles')
          .select('user_id')
          .eq('email', coachEmail)
          .limit(1);
      if (profiles.isEmpty) return false;
      final coachId = (profiles.first as Map)['user_id'] as String?;
      if (coachId == null) return false;
      await _client.from('coach_links').upsert({
        'coach_user_id': coachId,
        'viewer_user_id': viewerId,
      }, onConflict: 'coach_user_id,viewer_user_id');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> unlinkCoach(String coachUserId) async {
    final viewerId = AuthService.instance.currentUserId;
    if (viewerId == null) return;
    try {
      await _client
          .from('coach_links')
          .delete()
          .match({'coach_user_id': coachUserId, 'viewer_user_id': viewerId});
    } catch (_) {}
  }
}
