/// Abstraction over the remote data source for sync operations.
///
/// Isolates [SyncService] from the Supabase fluent API, making each class
/// independently testable and swappable.
abstract interface class IRemoteSyncClient {
  /// Returns the owner IDs accessible to [userId]:
  /// the user themselves, plus any coaches who have shared access.
  Future<List<String>> fetchAccessibleOwnerIds(String userId);

  /// Fetches rows from [table] belonging to [ownerIds] that were updated
  /// after [cursor] (when provided). Returns rows ordered by `updated_at`.
  Future<List<Map<String, dynamic>>> fetchTableRows(
    String table,
    List<String> ownerIds, {
    String? cursor,
  });

  /// Fetches rows from [table] whose `uuid` column matches any value in [uuids].
  /// Returns an empty list when [uuids] is empty.
  Future<List<Map<String, dynamic>>> fetchByUuids(
    String table,
    List<String> uuids,
  );

  /// Upserts [rows] into [table], using [onConflict] column(s) for deduplication.
  Future<void> upsertRows(
    String table,
    List<Map<String, dynamic>> rows, {
    required String onConflict,
  });
}
