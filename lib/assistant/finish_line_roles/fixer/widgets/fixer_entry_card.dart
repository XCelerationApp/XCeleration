import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/controller/fixer_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/widgets/resolve_sheet.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/fixer_entry.dart';
import 'package:xceleration/coach/bib_conflict_resolution/utils/ordinal.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// A single card in the Fixer's queue.
///
/// Unresolved: white card showing bib number, position, context message, and
/// optional "Recorded as" line. Tapping opens [ResolveSheet].
///
/// Resolved: green card showing checkmark, resolved runner name, and
/// bib/position/correction metadata.
class FixerEntryCard extends StatefulWidget {
  const FixerEntryCard({
    super.key,
    required this.entry,
    required this.controller,
  });

  final FixerEntry entry;
  final FixerController controller;

  @override
  State<FixerEntryCard> createState() => _FixerEntryCardState();
}

class _FixerEntryCardState extends State<FixerEntryCard> {
  bool _pressed = false;

  void _openResolve() {
    if (widget.entry.isResolved) return;
    widget.controller.clearSearch();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ResolveSheet(
        entry: widget.entry,
        controller: widget.controller,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    if (entry.isResolved) return _ResolvedCard(entry: entry);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _openResolve,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.surfaceColor
              : Colors.white,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(
            color: AppColors.borderColor,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '#${entry.bib}',
                  style: AppTypography.bibCompact.copyWith(
                    color: AppColors.darkColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  ordinal(entry.position),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.mediumColor,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.lightColor,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              entry.contextMessage,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.mediumColor,
              ),
            ),
            if (entry.runnerName != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Recorded as: ${entry.runnerName}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.mediumColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Resolved card ─────────────────────────────────────────────────────────────

class _ResolvedCard extends StatelessWidget {
  const _ResolvedCard({required this.entry});

  final FixerEntry entry;

  @override
  Widget build(BuildContext context) {
    final resolvedBib = entry.correctedBib ?? entry.bib;
    final name = entry.resolvedName ?? 'Runner #$resolvedBib';

    final suffix = [
      if (entry.correctedBib != null && entry.correctedBib != entry.bib)
        'bib corrected',
      if (entry.isNewRunner) 'new runner',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.statusFinished.withValues(alpha: AppOpacity.subtle),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(
          color: AppColors.statusFinished.withValues(alpha: AppOpacity.medium),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.statusFinished.withValues(alpha: AppOpacity.soft),
              borderRadius: BorderRadius.circular(AppBorderRadius.sm),
            ),
            child: Center(
              child: Text(
                '✓',
                style: AppTypography.smallBodySemibold.copyWith(
                  color: AppColors.statusFinished,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.smallBodySemibold.copyWith(
                    color: AppColors.darkColor,
                  ),
                ),
                Text(
                  '#$resolvedBib · ${ordinal(entry.position)} place'
                  '${suffix.isNotEmpty ? ' · $suffix' : ''}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.mediumColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
