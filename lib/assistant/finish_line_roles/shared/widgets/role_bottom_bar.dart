import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/overflow_menu_button.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Bottom action bar shared by the Verifier and Fixer role screens.
///
/// Shows a full-width animated leave/stop button on the left and an
/// [OverflowMenuButton] on the right. The button [label] and [buttonColor]
/// differ between roles — pass them from the screen level.
class RoleBottomBar extends StatefulWidget {
  const RoleBottomBar({
    super.key,
    required this.label,
    required this.buttonColor,
    required this.onTap,
    required this.menuItems,
  });

  /// Text displayed on the primary action button (e.g. "Stop Race", "Leave Race").
  final String label;

  /// Colour used for the button background tint and border.
  final Color buttonColor;

  /// Called when the primary action button is tapped.
  final VoidCallback onTap;

  /// Items shown in the overflow menu.
  final List<OverflowMenuItem> menuItems;

  @override
  State<RoleBottomBar> createState() => _RoleBottomBarState();
}

class _RoleBottomBarState extends State<RoleBottomBar> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: AppAnimations.fast,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: _pressed
                      ? widget.buttonColor.withValues(alpha: AppOpacity.light)
                      : widget.buttonColor.withValues(alpha: AppOpacity.faint),
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  border: Border.all(
                    color: widget.buttonColor.withValues(alpha: AppOpacity.strong),
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.label,
                    style: AppTypography.smallBodySemibold.copyWith(
                      color: widget.buttonColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OverflowMenuButton(items: widget.menuItems),
        ],
      ),
    );
  }
}
