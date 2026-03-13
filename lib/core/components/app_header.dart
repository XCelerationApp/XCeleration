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
/// Includes a large title, instructions button, role switcher, and settings.
///
/// Navigation is decoupled via [onRoleTap] and [onSettingsTap] callbacks —
/// screens own navigation; this shared component does not.
class AppHeader extends StatelessWidget {
  final String title;
  final Role currentRole;
  final TutorialManager tutorialManager;
  final TextStyle? titleStyle;

  /// Called when the user taps the role-switcher button.
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
          Flexible(
            child: Text(
              title,
              style: titleStyle ?? AppTypography.displayMedium,
              overflow: TextOverflow.ellipsis,
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
          CoachMark(
            id: 'role_bar_tutorial',
            tutorialManager: tutorialManager,
            config: const CoachMarkConfig(
              title: 'Switch Roles',
              alignmentX: AlignmentX.left,
              alignmentY: AlignmentY.bottom,
              description:
                  'Click here to switch between Coach, Timer, and Bib Recorder roles',
              icon: Icons.touch_app,
              type: CoachMarkType.targeted,
              backgroundColor: Color(0xFF1976D2),
              elevation: 12,
            ),
            child: _HeaderIconButton(
              icon: Icons.person_outline,
              onTap: onRoleTap,
            ),
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
