import '../../coach/race_screen/services/race_service.dart';
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

/// Simple service locator for dependency injection
/// This helps reduce coupling between services and makes testing easier
class ServiceLocator {
  static final Map<Type, Object> _services = {};

  /// Initialize all services
  static Future<void> initialize() async {
    Logger.d('Initializing services...');

    // Core services
    _services[EventBus] = EventBus.instance;

    // Database layer — one connection provider shared across all repositories
    final connProvider = DatabaseConnectionProvider();
    _services[IDatabaseConnectionProvider] = connProvider;

    // Write event bus — notified by repositories after every mutation
    final writeBus = DatabaseWriteBus();
    _services[DatabaseWriteBus] = writeBus;

    final runnerRepo = RunnerRepository(conn: connProvider, writeBus: writeBus);
    _services[IRunnerRepository] = runnerRepo;

    final teamRepo = TeamRepository(conn: connProvider, writeBus: writeBus);
    _services[ITeamRepository] = teamRepo;

    final raceRepo = RaceRepository(
        conn: connProvider, runnerRepo: runnerRepo, writeBus: writeBus);
    _services[IRaceRepository] = raceRepo;

    final resultsRepo =
        ResultsRepository(conn: connProvider, writeBus: writeBus);
    _services[IResultsRepository] = resultsRepo;

    // Consolidated Google service
    _services[GoogleService] = GoogleService.instance;
    await GoogleService.instance.initialize();

    // Feature services
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
