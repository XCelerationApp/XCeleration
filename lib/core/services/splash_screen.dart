import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_loading.dart';
import '../../shared/role_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import '../components/page_route_animations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Set up animations
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Wait until first frame is drawn, then remove the native splash screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Remove the native splash screen only after the first frame is rendered
      FlutterNativeSplash.remove();

      // Start animation
      _controller.forward();

      // Navigate after a delay
      Future.delayed(const Duration(milliseconds: 2500), () {
        _navigateToNextScreen();
      });
    });
  }

  void _navigateToNextScreen() {
    Navigator.of(context).pushReplacement(
      InitialPageRouteAnimation(
        child: const RoleScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primaryColor,
                        ColorUtils.withOpacity(AppColors.primaryColor, 0.85),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // Logo with animation
                    FadeTransition(
                      opacity: _fadeInAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: size.width * 0.35,
                          height: size.width * 0.35,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    ColorUtils.withOpacity(Colors.black, 0.2),
                                blurRadius: 15,
                                spreadRadius: 1,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: size.width * 0.25,
                              height: size.width * 0.25,
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  'XC',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: size.height * 0.05),

                    // App name with animation
                    FadeTransition(
                      opacity: _fadeInAnimation,
                      child: Column(
                        children: [
                          Text(
                            'XCeleration',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  blurRadius: 3.0,
                                  color:
                                      ColorUtils.withOpacity(Colors.black, 0.2),
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Race Timer',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: ColorUtils.withOpacity(Colors.white, 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Loading indicator - use a loading type that looks better on orange
                    AppLoading(
                      type: LoadingType.fadingCircle,
                      message: 'Initializing...',
                      color: Colors.white,
                      size: 50,
                    ),

                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
