/// Helpers for soft-deleting rows that carry a unique value.
///
/// Soft-deleted rows stay in their table so the delete can sync, but a
/// runner's bib number and a team's name must stay unique (locally, and per
/// coach in Supabase). Appending [releasedSuffix] to the value when the row is
/// deleted frees the original for a new runner or team.
abstract final class SoftDelete {
  /// Marker placed between the original value and the row's identity.
  static const marker = '~deleted~';

  /// Suffix that makes a deleted row's value unique: the local id plus the
  /// deletion timestamp.
  static String releasedSuffix(int id, String deletedAt) =>
      '$marker$id~$deletedAt';
}
