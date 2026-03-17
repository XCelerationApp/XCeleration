import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Uppercase section label used in the role lobby screens.
class RoleLobbySectionLabel extends StatelessWidget {
  const RoleLobbySectionLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTypography.bodySmall.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.mediumColor,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// Pressable session card shown in the role lobby.
///
/// Displays a [title], [subtitle], and a "Join" pill. Calls [onTap] when
/// the user taps anywhere on the card.
class RoleLobbySessionCard extends StatefulWidget {
  const RoleLobbySessionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<RoleLobbySessionCard> createState() => _RoleLobbySessionCardState();
}

class _RoleLobbySessionCardState extends State<RoleLobbySessionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.spring,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: AppTypography.smallBodySemibold.copyWith(
                      color: AppColors.darkColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.mediumColor,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: AppOpacity.faint),
                borderRadius: BorderRadius.circular(AppBorderRadius.full),
                border: Border.all(
                  color: AppColors.primaryColor.withValues(alpha: AppOpacity.strong),
                ),
              ),
              child: Text(
                'Join',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
