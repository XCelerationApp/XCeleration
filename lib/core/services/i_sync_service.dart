import 'package:xceleration/core/services/sync_service.dart';

abstract interface class ISyncService {
  Stream<SyncEvent> get syncEvents;
  Future<void> syncAll();

  /// Forgets how far each table has been pulled, so the next sync starts from
  /// the beginning. Called on sign-out: a cursor belongs to the account that
  /// set it, and left in place it makes the next account's first pull skip
  /// everything written before that point.
  Future<void> clearSyncCursors();

  Future<void> dispose();
}
