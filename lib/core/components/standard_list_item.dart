import 'package:flutter/material.dart';
import '../theme/app_animations.dart';
import '../theme/app_border_radius.dart';
import '../theme/app_colors.dart';
import '../theme/app_opacity.dart';
import '../theme/app_spacing.dart';
import '../theme/typography.dart';

/// A standardized list row that supports compact mode, press animations,
/// and leading/title/subtitle/trailing slot composition.
///
/// Use [StatefulWidget] + [AnimatedContainer] for press highlights —
/// see UI_STANDARD_SKILL.md for rationale.
class StandardListItem extends StatefulWidget {
  const StandardListItem({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isCompact = false,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Compact mode: tighter padding for data-dense screens.
  final bool isCompact;

  @override
  State<StandardListItem> createState() => _StandardListItemState();
}

class _StandardListItemState extends State<StandardListItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final hPad = widget.isCompact ? AppSpacing.sm : AppSpacing.lg;
    final vPad = widget.isCompact ? AppSpacing.xs : AppSpacing.md;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.spring,
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: Row(
          children: [
            widget.leading,
            SizedBox(width: widget.isCompact ? AppSpacing.sm : AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: AppTypography.bodyRegular),
                  if (widget.subtitle != null) ...[
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.subtitle!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.mediumColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.trailing != null) ...[
              SizedBox(width: AppSpacing.sm),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
