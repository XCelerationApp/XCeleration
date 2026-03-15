import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/grade_utils.dart';
import '../../../shared/models/database/runner.dart';
import '../../../shared/models/database/team.dart';
import '../controller/runners_management_controller.dart';

class RunnerListItem extends StatefulWidget {
  const RunnerListItem({
    super.key,
    required this.runner,
    required this.team,
    required this.onAction,
    required this.controller,
    this.isViewMode = false,
  });

  final Runner runner;
  final Team team;
  final Function(String) onAction;
  final RunnersManagementController controller;
  final bool isViewMode;

  @override
  State<RunnerListItem> createState() => _RunnerListItemState();
}

class _RunnerListItemState extends State<RunnerListItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final teamColor = widget.team.color ?? AppColors.primaryColor;
    final label = gradeLabel(widget.runner.grade);

    Widget row = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.isViewMode ? null : () => widget.onAction('Edit'),
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.spring,
        color: _pressed
            ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
            : Colors.transparent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  // Color dot + name
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: teamColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            widget.runner.name ?? '-',
                            style: AppTypography.smallBodyRegular.copyWith(
                              color: AppColors.darkColor,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Grade label
                  SizedBox(
                    width: 36,
                    child: Center(
                      child: Text(
                        label,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.mediumColor,
                        ),
                      ),
                    ),
                  ),
                  // Bib number — tabular figures for alignment
                  SizedBox(
                    width: 56,
                    child: Text(
                      widget.runner.bibNumber ?? '-',
                      textAlign: TextAlign.right,
                      style: AppTypography.smallBodySemibold.copyWith(
                        color: teamColor,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  // Swipe hint chevron
                  if (!widget.isViewMode) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.chevron_left,
                      size: 14,
                      color: AppColors.lightColor,
                    ),
                  ],
                ],
              ),
            ),
            // Indented divider matching prototype
            Divider(
              height: 1,
              indent: AppSpacing.lg,
              endIndent: AppSpacing.lg,
              color: AppColors.surfaceColor,
            ),
          ],
        ),
      ),
    );

    if (widget.isViewMode) return row;

    return Slidable(
      key: Key(widget.runner.bibNumber ?? ''),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => widget.onAction('Edit'),
            backgroundColor: AppColors.statusPreRace,
            foregroundColor: AppColors.backgroundColor,
            icon: Icons.edit,
          ),
          SlidableAction(
            onPressed: (_) => widget.onAction('Delete'),
            backgroundColor: AppColors.redColor,
            foregroundColor: AppColors.backgroundColor,
            icon: Icons.delete,
          ),
        ],
      ),
      child: row,
    );
  }
}
