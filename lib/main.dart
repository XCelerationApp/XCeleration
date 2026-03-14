// import 'dart:io'; // Unused
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'core/theme/typography.dart';
import 'core/services/splash_screen.dart';
import 'core/services/event_bus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'coach/race_screen/controller/race_screen_controller.dart';
import 'coach/races_screen/controller/races_controller.dart';
import 'core/services/geo_location_service.dart';
import 'core/services/post_frame_callback_scheduler.dart';
import 'coach/races_screen/services/races_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/tutorial_manager.dart';
import 'shared/models/database/master_race.dart';
import 'core/repositories/i_database_connection_provider.dart';
import 'core/services/database_write_bus.dart';
import 'core/services/sync_service.dart';
import 'core/services/remote_api_client.dart';
import 'core/services/supabase_remote_sync_client.dart';
import 'core/services/connectivity_sync_service.dart';
import 'core/services/i_sync_service.dart';
import 'core/services/service_locator.dart';

/// EventBus provider wrapper for global event management
class EventBusProvider extends ChangeNotifier {
  final EventBus eventBus = EventBus.instance;

  void fireEvent(String eventType, [dynamic data]) {
    Logger.d('EventBusProvider: Firing event $eventType with data: $data');
    eventBus.fire(eventType, data);
  }
}

// Production app entry point
void main() async {
  await _initializeApp();
}

// Common initialization
Future<void> _initializeApp() async {
  await dotenv.load(fileName: '.env');

  await SentryFlutter.init(
    (options) async {
      options.dsn = dotenv.env['SENTRY_DSN'] ?? '';
      options.tracesSampleRate = 1.0;
      options.diagnosticLevel = SentryLevel.warning;
      try {
        final info = await PackageInfo.fromPlatform();
        options.release =
            '${info.packageName}@${info.version}+${info.buildNumber}';
      } catch (_) {}
    },
    appRunner: () => _runApp(),
  );
}

void _runApp() async {
  // Initialize Flutter binding
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize the service locator (registers repos, write bus, etc.)
  await ServiceLocator.initialize();

  // Initialize Supabase eagerly so it is ready before any screen is reached.
  final remoteApi = RemoteApiClient();
  await remoteApi.init();

  // Wire up concrete service instances once at startup
  final syncService = SyncService(
    db: ServiceLocator.get<IDatabaseConnectionProvider>(),
    remote: remoteApi,
    syncClient: SupabaseRemoteSyncClient(remote: remoteApi),
    auth: AuthService.instance,
  );
  final connectivitySyncService = ConnectivitySyncService(
    sync: syncService,
    auth: AuthService.instance,
    writeStream: ServiceLocator.get<DatabaseWriteBus>().writes,
  );
  connectivitySyncService.start();

  runApp(
    MultiProvider(
      providers: [
        Provider<ISyncService>.value(value: syncService),
        Provider<ConnectivitySyncService>.value(value: connectivitySyncService),
        ChangeNotifierProvider(create: (context) => EventBusProvider()),
        ChangeNotifierProvider(
          create: (context) => RaceController(
              masterRace: MasterRace.getInstance(0),
              parentController: RacesController(racesService: RacesService(), authService: AuthService.instance, eventBus: EventBus.instance, geoLocationService: GeoLocationService(), postFrameCallbackScheduler: WidgetsBindingAdapter(), tutorialManager: TutorialManager(), syncStream: syncService.syncEvents)),
        ),
        ChangeNotifierProvider(
            create: (context) => RacesController(racesService: RacesService(), authService: AuthService.instance, eventBus: EventBus.instance, geoLocationService: GeoLocationService(), postFrameCallbackScheduler: WidgetsBindingAdapter(), tutorialManager: TutorialManager(), syncStream: syncService.syncEvents)),
      ],
      child: const MyApp(),
    ),
  );

  // Kick off a background sync shortly after startup
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await syncService.syncAll();
    } catch (_) {}
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Get app name from environment or use default
    final appName = dotenv.env['APP_NAME'];

    return MaterialApp(
      title: appName,
      theme: _buildTheme(),
      home: const SplashScreen(),
      showPerformanceOverlay: false,
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      primaryColor: AppColors.backgroundColor,
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: Colors.deepOrange,
      ).copyWith(
        secondary: AppColors.backgroundColor,
        onPrimary: AppColors.lightColor,
      ),
      scaffoldBackgroundColor: AppColors.backgroundColor,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.darkColor,
        selectionColor: Colors.grey[300],
        selectionHandleColor: AppColors.mediumColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navBarColor,
        foregroundColor: AppColors.navBarTextColor,
        titleTextStyle:
            const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.navBarTextColor,
        unselectedLabelColor: AppColors.backgroundColor,
        indicator: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.navBarTextColor, width: 0),
          ),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge,
        titleLarge: AppTypography.titleSemibold,
        bodyLarge: AppTypography.bodyRegular,
        bodyMedium: AppTypography.bodyRegular,
        labelLarge: AppTypography.bodySemibold,
        bodySmall: TextStyle(color: AppColors.mediumColor),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: AppColors.navBarTextColor,
        textTheme: ButtonTextTheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      iconTheme: IconThemeData(color: AppColors.mediumColor),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: TextStyle(color: AppColors.darkColor),
          foregroundColor: AppColors.darkColor,
        ),
      ),
    );
  }
}
