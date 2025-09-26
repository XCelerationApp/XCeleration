import 'package:flutter/material.dart';

class BasePageRouteAnimation extends PageRouteBuilder {
  final Widget child;
  final Duration duration;

  BasePageRouteAnimation({
    required this.child,
    this.duration = const Duration(milliseconds: 500),
  }) : super(
          transitionDuration: duration,
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const curve = Curves.easeInOut;
            var fadeAnimation = animation.drive(CurveTween(curve: curve));

            return FadeTransition(
              opacity: fadeAnimation,
              child: child,
            );
          },
        );
}

class RolePageRouteAnimation extends BasePageRouteAnimation {
  RolePageRouteAnimation({required super.child})
      : super(duration: const Duration(milliseconds: 300));
}

class SettingsPageRouteAnimation extends BasePageRouteAnimation {
  SettingsPageRouteAnimation({required super.child})
      : super(duration: const Duration(milliseconds: 300));
}

class InitialPageRouteAnimation extends BasePageRouteAnimation {
  InitialPageRouteAnimation({required super.child})
      : super(duration: const Duration(milliseconds: 500));
}

class DefaultPageRouteAnimation extends BasePageRouteAnimation {
  DefaultPageRouteAnimation({required super.child});
  // Uses the default 500ms duration from BasePageRouteAnimation
}
