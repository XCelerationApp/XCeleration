import 'package:flutter/material.dart';

class SlidingPageView extends StatefulWidget {
  final Widget firstPage;
  final Widget secondPage;
  final String? secondPageTitle;
  final bool showSecondPage;
  final VoidCallback? onBackToFirst;
  final Duration animationDuration;

  const SlidingPageView({
    super.key,
    required this.firstPage,
    required this.secondPage,
    this.secondPageTitle,
    required this.showSecondPage,
    this.onBackToFirst,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<SlidingPageView> createState() => _SlidingPageViewState();
}

class _SlidingPageViewState extends State<SlidingPageView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start from right
      end: Offset.zero, // End at center
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Custom fade animation that finishes at halfway point when opening
    // and starts at halfway point when closing
    _fadeAnimation = _animationController.drive(_HalfwayFadeTween());
  }

  @override
  void didUpdateWidget(SlidingPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showSecondPage != oldWidget.showSecondPage) {
      if (widget.showSecondPage) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: [
          // First page (always present)
          Positioned.fill(
            child: widget.firstPage,
          ),
          // Second page (slides over the first) - header and content move together
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Material(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Column(
                        children: [
                          // Header with back arrow and title (part of sliding content)
                          if (widget.secondPageTitle != null)
                            Container(
                              padding: const EdgeInsets.only(
                                  left: 8, top: 8, bottom: 8),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back),
                                    onPressed: widget.onBackToFirst,
                                    tooltip: 'Back',
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        widget.secondPageTitle!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ),
                                  // Add invisible spacer to balance the back button
                                  const SizedBox(width: 48),
                                ],
                              ),
                            ),
                          // Page content
                          Expanded(
                            child: widget.secondPage,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom animatable that handles fade timing:
/// - Opening: fade from 0.0 to 1.0 during first half (0.0 to 0.5)
/// - Closing: fade from 1.0 to 0.0 during second half (0.5 to 0.0)
class _HalfwayFadeTween extends Animatable<double> {
  @override
  double transform(double t) {
    if (t <= 0.5) {
      // First half: fade in completely (0.0 to 1.0)
      return (t * 2.0).clamp(0.0, 1.0);
    } else {
      // Second half: stay fully opaque
      return 1.0;
    }
  }
}
