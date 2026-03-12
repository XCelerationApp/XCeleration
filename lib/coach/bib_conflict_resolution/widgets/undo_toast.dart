import 'package:flutter/material.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

/// Floating dark toast shown after a conflict is resolved.
///
/// Slides up on appearance, shows a draining green bar over 1800 ms,
/// and calls [onDone] when the bar reaches zero. Tapping "Undo" calls
/// [onUndo] and stops the timer immediately.
class UndoToast extends StatefulWidget {
  const UndoToast({
    super.key,
    required this.label,
    required this.onUndo,
    required this.onDone,
  });

  final String label;
  final VoidCallback onUndo;
  final VoidCallback onDone;

  @override
  State<UndoToast> createState() => _UndoToastState();
}

class _UndoToastState extends State<UndoToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  // Entry takes AppAnimations.standard (250 ms) out of the 1800 ms total.
  static const _totalMs = 1800;
  // 250 / 1800 — Duration.inMilliseconds is not usable in a const expression.
  static const _entryFraction = 250 / _totalMs;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: _totalMs),
      vsync: this,
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onDone();
        }
      })
      ..forward();

    final entryCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, _entryFraction, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(entryCurve);

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(entryCurve);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleUndo() {
    _controller.stop();
    widget.onUndo();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: _ToastBody(
          label: widget.label,
          controller: _controller,
          onUndo: _handleUndo,
        ),
      ),
    );
  }
}

class _ToastBody extends StatelessWidget {
  const _ToastBody({
    required this.label,
    required this.controller,
    required this.onUndo,
  });

  final String label;
  final AnimationController controller;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        boxShadow: AppShadows.high,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        child: Stack(
          children: [
            Padding(
              // Extra 3 px bottom padding reserves space for the draining bar.
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md + 3,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Conflict resolved',
                          style: AppTypography.smallBodySemibold.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          label,
                          style: AppTypography.caption.copyWith(
                            color: Colors.white.withValues(alpha: AppOpacity.solid),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _UndoButton(onUndo: onUndo),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3,
              child: _DrainingBar(controller: controller),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrainingBar extends StatelessWidget {
  const _DrainingBar({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Colors.white.withValues(alpha: AppOpacity.faint),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 1 - controller.value,
                child: const ColoredBox(color: Colors.green),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UndoButton extends StatelessWidget {
  const _UndoButton({required this.onUndo});

  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onUndo,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: AppOpacity.medium),
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: Text(
          'Undo',
          style: AppTypography.smallBodySemibold.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
