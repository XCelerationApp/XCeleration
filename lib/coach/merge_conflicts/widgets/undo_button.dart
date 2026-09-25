import 'package:flutter/material.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

/// Takes back the last + or X press in a conflict batch. Sits beside
/// "Resolve Conflict" and appears only once there is something to take back.
class UndoButton extends StatelessWidget {
  const UndoButton({
    super.key,
    required this.label,
    required this.onUndo,
  });

  /// What the press will take back, e.g. 'removing 15:42.64'.
  final String label;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Undo $label',
      child: OutlinedButton.icon(
        onPressed: onUndo,
        icon: const Icon(Icons.undo, size: AppSpacing.lg),
        label: Text(
          'Undo',
          style: AppTypography.bodySemibold.copyWith(fontSize: AppSpacing.lg),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryColor,
          side: BorderSide(
            color: AppColors.primaryColor.withValues(alpha: AppOpacity.solid),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.sm),
          ),
        ),
      ),
    );
  }
}
