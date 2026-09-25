import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_border_radius.dart';
import '../theme/typography.dart';
import '../services/tutorial_manager.dart';
import 'coach_mark.dart';
import '../../shared/role_bar/models/role_enums.dart';
import '../../shared/role_bar/widgets/instructions_banner.dart';

/// Top-of-screen header used across all role screens.
/// Includes a large title that opens the role switcher, an instructions
/// button, and settings.
///
/// Navigation is decoupled via [onRoleTap] and [onSettingsTap] callbacks —
/// screens own navigation; this shared component does not.
class AppHeader extends StatelessWidget {
  final String title;
  final Role currentRole;
  final TutorialManager tutorialManager;
  final TextStyle? titleStyle;

  /// Called when the user taps the title, to switch roles.
  /// The parent screen is responsible for showing the role selector.
  final VoidCallback onRoleTap;

  /// Called when the user taps the settings button.
  /// The parent screen is responsible for navigating to settings.
  final VoidCallback onSettingsTap;

  const AppHeader({
    super.key,
    required this.title,
    required this.currentRole,
    required this.tutorialManager,
    required this.onRoleTap,
    required this.onSettingsTap,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        topPadding + AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Tapping the title switches roles; the arrow beside it says so.
          // It shrinks to fit beside the buttons at a large text size, rather
          // than cutting the title down to "My ...". There used to be a
          // person button for this too, which looked like an account page.
          Flexible(
            child: CoachMark(
              id: 'role_bar_tutorial',
              tutorialManager: tutorialManager,
              config: const CoachMarkConfig(
                title: 'Switch Roles',
                // Opens rightward from the title, at the left edge.
                alignmentX: AlignmentX.right,
                alignmentY: AlignmentY.bottom,
                description:
                    'Tap the title to switch between Coach, Timer, and Bib Recorder',
                icon: Icons.touch_app,
                type: CoachMarkType.targeted,
                backgroundColor: Color(0xFF1976D2),
                elevation: 12,
              ),
              child: Semantics(
                button: true,
                label: '$title. Switch roles',
                excludeSemantics: true,
                child: GestureDetector(
                  key: const ValueKey('app_header_title'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onRoleTap,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          style: titleStyle ?? AppTypography.displayMedium,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 28, color: AppColors.mediumColor),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _HeaderIconButton(
            icon: Icons.info_outline,
            highlight: true,
            onTap: () =>
                InstructionsBanner.showInstructionsSheetManual(context, currentRole),
          ),
          const SizedBox(width: AppSpacing.sm),
          _HeaderIconButton(
            icon: Icons.settings_outlined,
            onTap: onSettingsTap,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: highlight
              ? AppColors.selectedRoleColor
              : AppColors.unselectedRoleColor,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        ),
        child: Icon(
          icon,
          size: AppSpacing.xl,
          color: highlight ? AppColors.primaryColor : AppColors.darkColor,
        ),
      ),
    );
  }
}
