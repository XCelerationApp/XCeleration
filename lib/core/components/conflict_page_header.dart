import 'package:flutter/material.dart';
import '../theme/app_animations.dart';
import '../theme/app_border_radius.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/typography.dart';

/// The top of a conflicts page: Back, what is being sorted out and for which
/// race. Bib and timing conflicts share it, so the two pages look and work
/// the same.
class ConflictNavBar extends StatelessWidget {
  const ConflictNavBar({
    super.key,
    required this.title,
    required this.raceName,
    required this.onBack,
  });

  final String title;
  final String raceName;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back,
              size: 16,
              color: AppColors.primaryColor,
            ),
            label: Text(
              'Back',
              style: AppTypography.smallBodySemibold.copyWith(
                color: AppColors.primaryColor,
              ),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(title, style: AppTypography.smallBodySemibold),
                const SizedBox(height: 2),
                Text(
                  raceName,
                  style: AppTypography.smallCaption.copyWith(
                    color: AppColors.mediumColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 52),
        ],
      ),
    );
  }
}

/// How many of a page's conflicts are resolved, as a count and a bar.
class ConflictProgress extends StatelessWidget {
  const ConflictProgress({
    super.key,
    required this.resolved,
    required this.total,
  });

  final int resolved;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? resolved / total : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CONFLICTS',
                style: AppTypography.extraSmall.copyWith(
                  color: AppColors.primaryColor,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '$resolved / $total resolved',
                style: AppTypography.extraSmall.copyWith(
                  color: AppColors.mediumColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppBorderRadius.full),
            child: SizedBox(
              height: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.lightColor),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: fraction),
                      duration: AppAnimations.standard,
                      curve: AppAnimations.spring,
                      builder: (context, value, _) => FractionallySizedBox(
                        widthFactor: value,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryColor,
                                AppColors.primaryGradientEnd,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
