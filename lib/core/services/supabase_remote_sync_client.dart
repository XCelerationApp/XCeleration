import 'package:xceleration/core/services/i_remote_api_client.dart';
import 'package:xceleration/core/services/i_remote_sync_client.dart';
import 'package:xceleration/core/utils/logger.dart';

/// Supabase-backed implementation of [IRemoteSyncClient].
///
/// Wraps the Supabase fluent query API so that [SyncService] never touches
/// Supabase directly, making [SyncService] fully unit-testable via a mock.
class SupabaseRemoteSyncClient implements IRemoteSyncClient {
  final IRemoteApiClient _remote;

  SupabaseRemoteSyncClient({required IRemoteApiClient remote})
      : _remote = remote;

  @override
  Future<List<String>> fetchAccessibleOwnerIds(String userId) async {
    try {
      final List links = await _remote.client
          .from('coach_links')
          .select('coach_user_id')
          .eq('viewer_user_id', userId);
      final coachIds = links
          .map((e) => (e as Map)['coach_user_id']?.toString())
          .whereType<String>()
          .toList();
      return [userId, ...coachIds];
    } catch (_) {
      // Optional table — fall back to self only if it doesn't exist yet.
      return [userId];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTableRows(
    String table,
    List<String> ownerIds, {
    String? cursor,
  }) async {
    final query = _remote.client.from(table).select();
    if (ownerIds.isNotEmpty) {
      if (ownerIds.length == 1) {
        query.eq('owner_user_id', ownerIds.first);
      } else {
        final orExpr = ownerIds.map((id) => 'owner_user_id.eq.$id').join(',');
        query.or(orExpr);
      }
    }
    if (cursor != null && cursor.isNotEmpty) {
      query.gt('updated_at', cursor);
    }
    final List data = await query.order('updated_at').limit(1000);
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchByUuids(
    String table,
    List<String> uuids,
  ) async {
    if (uuids.isEmpty) return [];
    final rows =
        await _remote.client.from(table).select().inFilter('uuid', uuids);
    return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<void> upsertRows(
    String table,
    List<Map<String, dynamic>> rows, {
    required String onConflict,
  }) async {
    await _remote.client.from(table).upsert(rows, onConflict: onConflict);
    Logger.d('Upserted ${rows.length} rows to $table');
  }
}
