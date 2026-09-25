import '../../coach/race_screen/services/i_race_service.dart';
import '../../coach/race_screen/services/race_service.dart';
import '../../spectator/services/spectator_storage_service.dart';
import '../repositories/database_connection_provider.dart';
import '../repositories/i_database_connection_provider.dart';
import '../repositories/i_race_repository.dart';
import '../repositories/i_results_repository.dart';
import '../repositories/i_runner_repository.dart';
import '../repositories/i_team_repository.dart';
import '../repositories/race_repository.dart';
import '../repositories/results_repository.dart';
import '../repositories/runner_repository.dart';
import '../repositories/team_repository.dart';
import '../utils/logger.dart';
import 'database_write_bus.dart';
import 'event_bus.dart';
import 'google_service.dart';

/// Simple service locator for dependency injection.
///
/// The active instance is held in [_active]. Production code uses the default
/// singleton; tests replace it with a fresh [ServiceLocator] to get full
/// isolation without requiring [reset] calls between runs:
///
/// ```dart
/// setUp(() => ServiceLocator.replaceForTesting(ServiceLocator()));
/// tearDown(() => ServiceLocator.restoreDefault());
/// ```
class ServiceLocator {
  ServiceLocator();

  final Map<Type, Object> _services = {};

  // The active locator used by all static convenience methods.
  static ServiceLocator _active = ServiceLocator();

  /// Replace the active locator. Call this in test setUp.
  static void replaceForTesting(ServiceLocator locator) => _active = locator;

  /// Restore the default (empty) locator. Call this in test tearDown.
  static void restoreDefault() => _active = ServiceLocator();

  /// Initialize all services on the active locator.
  static Future<void> initialize() async {
    Logger.d('Initializing services...');

    // Core services
    _active._services[EventBus] = EventBus.instance;

    // Database layer — one connection provider shared across all repositories
    final connProvider = DatabaseConnectionProvider();
    _active._services[IDatabaseConnectionProvider] = connProvider;

    // Write event bus — notified by repositories after every mutation
    final writeBus = DatabaseWriteBus();
    _active._services[DatabaseWriteBus] = writeBus;

    final runnerRepo = RunnerRepository(conn: connProvider, writeBus: writeBus);
    _active._services[IRunnerRepository] = runnerRepo;

    final teamRepo = TeamRepository(conn: connProvider, writeBus: writeBus);
    _active._services[ITeamRepository] = teamRepo;

    final raceRepo = RaceRepository(
        conn: connProvider, runnerRepo: runnerRepo, writeBus: writeBus);
    _active._services[IRaceRepository] = raceRepo;

    final resultsRepo =
        ResultsRepository(conn: connProvider, writeBus: writeBus);
    _active._services[IResultsRepository] = resultsRepo;

    // Consolidated Google service — registered here for DI; initialization is
    // deferred to first use (GoogleService.signIn() calls initialize() lazily).
    _active._services[GoogleService] = GoogleService.instance;

    // Feature services — registered behind interfaces for testability.
    _active._services[IRaceService] = RaceService();
    _active._services[SpectatorStorageService] = SpectatorStorageService.instance;

    Logger.d('Services initialized successfully');
  }

  /// Get a service instance.
  static T get<T extends Object>() {
    final service = _active._services[T];
    if (service == null) {
      throw Exception('Service of type $T is not registered');
    }
    return service as T;
  }

  /// Register a service instance on the active locator.
  static void register<T extends Object>(T service) {
    _active._services[T] = service;
  }

  /// Check if a service is registered on the active locator.
  static bool isRegistered<T extends Object>() =>
      _active._services.containsKey(T);

  /// Clear all services on the active locator (kept for backward compatibility;
  /// prefer [replaceForTesting] + [restoreDefault] in tests).
  static void reset() {
    _active._services.clear();
  }
}

/// Extension to make service access more convenient.
extension ServiceLocatorExtension on Object {
  T getService<T extends Object>() => ServiceLocator.get<T>();
}
