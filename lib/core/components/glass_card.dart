import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.backgroundOpacity = 0.92,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final double backgroundOpacity;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: backgroundOpacity),
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.7),
              width: 1,
            ),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
