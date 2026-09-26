import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../../shared/role_screen.dart';

/// The app's first screen: the role screen, with the native launch screen
/// (the XCeleration wordmark on orange) kept up until it has drawn.
///
/// There used to be a second, Flutter-drawn splash here ("Initializing…")
/// held for a fixed 2.5 seconds after everything had already loaded.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => FlutterNativeSplash.remove());
  }

  @override
  Widget build(BuildContext context) => const RoleScreen();
}
