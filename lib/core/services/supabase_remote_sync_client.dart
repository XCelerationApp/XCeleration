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
  Future<List<Map<String, dynamic>>> fetchTableRows(
    String table,
    String ownerId, {
    String? cursor,
  }) async {
    // Postgrest filter methods return a new builder rather than mutating the
    // receiver, so every filter must be reassigned or it is silently dropped.
    var query =
        _remote.client.from(table).select().eq('owner_user_id', ownerId);
    if (cursor != null && cursor.isNotEmpty) {
      query = query.gt('updated_at', cursor);
    }
    // Ascending, so a page that hits the limit ends at the newest row it
    // contains and the next pull resumes from there without skipping rows.
    final List data =
        await query.order('updated_at', ascending: true).limit(1000);
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
