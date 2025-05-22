import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'core/theme/typography.dart';
import 'core/services/splash_screen.dart';
import 'core/services/event_bus.dart';
import 'config/app_config.dart';

Process? _flaskProcess;

// Global app configuration that can be accessed throughout the app
late AppConfig appConfig;

/// EventBus provider wrapper for global event management
class EventBusProvider extends ChangeNotifier {
  final EventBus eventBus = EventBus.instance;
  
  void fireEvent(String eventType, [dynamic data]) {
    debugPrint('EventBusProvider: Firing event $eventType with data: $data');
    eventBus.fire(eventType, data);
  }
}

// Production app entry point
void main() {
  // Use the configuration from environment variables or defaults
  mainCommon(AppConfig.fromEnvironment());
}

// Development app entry point - also uses environment variables
void mainDev() {
  // The configuration is automatically determined from dart-define parameters
  mainCommon(AppConfig.fromEnvironment());
}

// Common initialization for all flavors
void mainCommon(AppConfig config) async {
  // Store the config for later use
  appConfig = config;

  // This is important to ensure the native splash screen works correctly
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Preserve the native splash screen until the app is ready
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Lock the orientation to portrait mode
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        // Add the EventBusProvider at app level to ensure it's available everywhere
        ChangeNotifierProvider(
          create: (context) => EventBusProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}


Future<void> startFlaskServer() async {
  debugPrint('Starting Flask Server...');
  _flaskProcess = await Process.start(
      'python', ['lib/server/mnist_image_classification.py']);
}

void stopFlaskServer() {
  debugPrint('Stopping Flask Server');
  _flaskProcess?.kill(); // Stop the Flask server
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use title from app configuration
    return MaterialApp(
      title: appConfig.appName,
      theme: ThemeData(
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
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        tabBarTheme: TabBarTheme(
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
      ),
      home: const SplashScreen(),
    );
  }
}
