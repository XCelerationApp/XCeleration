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
import 'shared/models/database/master_race.dart';
import 'core/services/sync_service.dart';

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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => EventBusProvider()),
        ChangeNotifierProvider(
          create: (context) => RaceController(
              masterRace: MasterRace.getInstance(0),
              parentController: RacesController()),
        ),
        ChangeNotifierProvider(create: (context) => RacesController()),
      ],
      child: const MyApp(),
    ),
  );

  // Kick off a background sync shortly after startup
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await SyncService.instance.syncAll();
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
