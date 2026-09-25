/// Timestamps written to `updated_at` for sync.
///
/// Always UTC with an explicit `Z`. Supabase stores `updated_at` as
/// `timestamptz` and reads an offset-less string as UTC, so writing local time
/// without an offset would shift a US device's rows hours into the past and
/// break last-write-wins comparisons and pull cursors.
abstract final class SyncTimestamp {
  static String now() => DateTime.now().toUtc().toIso8601String();
}
