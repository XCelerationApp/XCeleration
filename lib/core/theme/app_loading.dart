import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Loading widget types
enum LoadingType {
  /// Circle spinner
  circle,
  
  /// Double bounce
  doubleBounce,
  
  /// Wave
  wave,
  
  /// Fading circle
  fadingCircle,
  
  /// Fading cube
  fadingCube,
  
  /// Pulse
  pulse,
  
  /// Three bounce
  threeBounce
}

/// Custom loading indicator widget
class AppLoading extends StatelessWidget {
  /// Type of loading animation
  final LoadingType type;
  
  /// Color of the loading animation
  final Color? color;
  
  /// Size of the loading animation
  final double size;
  
  /// Optional message to display below the loading indicator
  final String? message;
  
  /// Creates a loading indicator
  const AppLoading({
    super.key,
    this.type = LoadingType.fadingCircle,
    this.color,
    this.size = 50.0,
    this.message,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loadingColor = color ?? theme.colorScheme.primary;
    
    Widget loadingWidget;
    
    switch (type) {
      case LoadingType.circle:
        loadingWidget = SpinKitCircle(
          color: loadingColor,
          size: size,
        );
        break;
      case LoadingType.doubleBounce:
        loadingWidget = SpinKitDoubleBounce(
          color: loadingColor,
          size: size,
        );
        break;
      case LoadingType.wave:
        loadingWidget = SpinKitWave(
          color: loadingColor,
          size: size,
        );
        break;
      case LoadingType.fadingCircle:
        loadingWidget = SpinKitFadingCircle(
          color: loadingColor,
          size: size,
        );
        break;
      case LoadingType.fadingCube:
        loadingWidget = SpinKitFadingCube(
          color: loadingColor,
          size: size,
        );
        break;
      case LoadingType.pulse:
        loadingWidget = SpinKitPulse(
          color: loadingColor,
          size: size,
        );
        break;
      case LoadingType.threeBounce:
        loadingWidget = SpinKitThreeBounce(
          color: loadingColor,
          size: size,
        );
        break;
    }
    
    // If there's a message, return a column with the loading widget and the message
    if (message != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          loadingWidget,
          const SizedBox(height: 16),
          Text(
            message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              // color: theme.colorScheme.onSurface.withAlpha(180),
              color: AppColors.backgroundColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    
    // Otherwise, just return the loading widget
    return loadingWidget;
  }
}

/// Full screen loading overlay
class AppLoadingOverlay extends StatelessWidget {
  /// Whether to show the loading overlay
  final bool isLoading;
  
  /// Child widget to display behind the loading overlay
  final Widget child;
  
  /// Type of loading animation
  final LoadingType type;
  
  /// Color of the loading animation
  final Color? color;
  
  /// Size of the loading animation
  final double size;
  
  /// Background color of the overlay
  final Color? backgroundColor;
  
  /// Creates a loading overlay
  const AppLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.type = LoadingType.fadingCircle,
    this.color,
    this.size = 50.0,
    this.backgroundColor,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: backgroundColor ?? theme.colorScheme.surface.withAlpha(180),
            child: Center(
              child: AppLoading(
                type: type,
                color: color,
                size: size,
              ),
            ),
          ),
      ],
    );
  }
}
