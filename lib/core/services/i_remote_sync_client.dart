/// Abstraction over the remote data source for sync operations.
///
/// Isolates [SyncService] from the Supabase fluent API, making each class
/// independently testable and swappable.
abstract interface class IRemoteSyncClient {
  /// Fetches rows from [table] owned by [ownerId] that were updated after
  /// [cursor] (when provided). Returns rows ordered by `updated_at`.
  ///
  /// Only ever one owner: the coach's database holds their own races.
  /// Another coach's runners can share bib numbers with theirs, which the
  /// server allows (bibs are unique per coach) but the phone does not.
  Future<List<Map<String, dynamic>>> fetchTableRows(
    String table,
    String ownerId, {
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
