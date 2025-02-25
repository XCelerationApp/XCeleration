import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../utils/app_colors.dart';
import 'role_screen.dart';

class InitializationScreen extends StatefulWidget {
  const InitializationScreen({super.key});

  @override
  InitializationScreenState createState() => InitializationScreenState();
}

class InitializationScreenState extends State<InitializationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Color?> _backgroundAnimation;
  bool _showText = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 33.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.5)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 67.0,
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 80.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 20.0,
      ),
    ]).animate(_controller);

    _backgroundAnimation = ColorTween(
      begin: AppColors.primaryColor, // Deep Orange (matches splash screen)
      end: AppColors.primaryColor.withAlpha((0.9 * 255).round()),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeInOut),
    ));

    // Start with a tiny delay to ensure smooth transition from splash screen
    Future.delayed(const Duration(milliseconds: 100), () async {
      FlutterNativeSplash.remove();
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      // Start the animation
      _controller.forward();
      
      // After 1 second, show the text
      // await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        setState(() {
          _showText = true;
        });
      }

      // After animation completes, navigate to welcome screen
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
              opacity: animation,
              child: const RoleScreen(),
            ),
            transitionDuration: const Duration(milliseconds: 2000),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Handle error case if needed
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _backgroundAnimation.value,
          body: Center(
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_showText) ...[
                      const SizedBox(height: 60),
                    ],
                    if (_showText) ...[
                      const SizedBox(height: 20),
                      Text(
                        'XCelerate',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: AppColors.backgroundColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}