import '../utils/logger.dart';
import '../../utils/database_helper.dart';
import 'event_bus.dart';
import 'google_service.dart';
import '../../features/timing/services/timing_service.dart';
import '../../features/race_management/services/race_service.dart';

/// Simple service locator for dependency injection
/// This helps reduce coupling between services and makes testing easier
class ServiceLocator {
  static final Map<Type, Object> _services = {};

  /// Initialize all services
  static Future<void> initialize() async {
    Logger.d('Initializing services...');

    // Core services
    _services[EventBus] = EventBus.instance;
    _services[DatabaseHelper] = DatabaseHelper.instance;

    // Consolidated Google service
    _services[GoogleService] = GoogleService.instance;
    await GoogleService.instance.initialize();

    // Feature services
    _services[TimingService] = TimingService();
    _services[RaceService] = RaceService();

    Logger.d('Services initialized successfully');
  }

  /// Get a service instance
  static T get<T extends Object>() {
    final service = _services[T];
    if (service == null) {
      throw Exception('Service of type $T is not registered');
    }
    return service as T;
  }

  /// Register a service instance
  static void register<T extends Object>(T service) {
    _services[T] = service;
  }

  /// Check if a service is registered
  static bool isRegistered<T extends Object>() => _services.containsKey(T);

  /// Reset all services (useful for testing)
  static void reset() {
    _services.clear();
  }
}

/// Extension to make service access more convenient
extension ServiceLocatorExtension on Object {
  T getService<T extends Object>() => ServiceLocator.get<T>();
}
