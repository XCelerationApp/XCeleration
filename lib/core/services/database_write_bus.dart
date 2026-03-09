import 'dart:async';

/// Broadcast channel that emits a void event after every local database write.
///
/// Inject this into repositories that perform writes so they can call [notify]
/// after each mutation. Consumers (e.g. [ConnectivitySyncService]) subscribe to
/// [writes] to react to local changes (e.g. debounced auto-sync on Wi-Fi).
class DatabaseWriteBus {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get writes => _controller.stream;

  void notify() {
    if (!_controller.isClosed) _controller.add(null);
  }

  void dispose() => _controller.close();
}
