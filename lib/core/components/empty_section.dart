import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_animations.dart';
import '../theme/app_opacity.dart';
import '../theme/typography.dart';

/// A per-section empty state with a circular icon container, bold title,
/// and a gray subtitle. Fades in on first render.
class EmptySection extends StatefulWidget {
  const EmptySection({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  State<EmptySection> createState() => _EmptySectionState();
}

class _EmptySectionState extends State<EmptySection> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: AppAnimations.reveal,
      curve: AppAnimations.enter,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconContainer(icon: widget.icon),
              const SizedBox(height: AppSpacing.lg),
              Text(widget.title, style: AppTypography.bodyMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.subtitle,
                style: AppTypography.caption.copyWith(
                  color: AppColors.mediumColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconContainer extends StatelessWidget {
  const _IconContainer({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.xxxl + AppSpacing.xl,
      height: AppSpacing.xxxl + AppSpacing.xl,
      decoration: BoxDecoration(
        color: AppColors.darkColor.withValues(alpha: AppOpacity.faint),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: AppSpacing.xxl,
        color: AppColors.mediumColor.withValues(alpha: AppOpacity.solid),
      ),
    );
  }
}
