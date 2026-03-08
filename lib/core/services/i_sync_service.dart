import 'package:xceleration/core/services/sync_service.dart';

abstract interface class ISyncService {
  Stream<SyncEvent> get syncEvents;
  Future<void> syncAll();
  Future<void> setSyncMode(String mode);
  Future<String> getSyncMode();
}
