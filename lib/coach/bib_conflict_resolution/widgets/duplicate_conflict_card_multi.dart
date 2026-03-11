part of 'duplicate_conflict_card.dart';

// ---------------------------------------------------------------------------
// Step 1 header sub-widgets (used by both 2-occ and N-occ paths)
// ---------------------------------------------------------------------------

class _DupBadgeRow extends StatelessWidget {
  const _DupBadgeRow({required this.conflict});

  final MockDuplicateConflict conflict;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.statusSetup.withValues(alpha: AppOpacity.light),
            borderRadius: BorderRadius.circular(AppBorderRadius.sm),
          ),
          child: const Icon(Icons.bolt, color: AppColors.statusSetup, size: 22),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DUPLICATE BIB',
              style: AppTypography.extraSmall.copyWith(
                letterSpacing: 0.5,
                color: AppColors.statusSetup,
              ),
            ),
            Text(
              '#${conflict.bibNumber}',
              style: AppTypography.titleSemibold.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.statusSetup.withValues(alpha: AppOpacity.light),
            borderRadius: BorderRadius.circular(AppBorderRadius.full),
          ),
          child: Text(
            '${conflict.occurrences.length}×',
            style: AppTypography.smallBodySemibold.copyWith(
              color: AppColors.statusSetup,
            ),
          ),
        ),
      ],
    );
  }
}

class _KnownRunnerCard extends StatelessWidget {
  const _KnownRunnerCard({required this.conflict});

  final MockDuplicateConflict conflict;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F6),
        border: Border.all(color: const Color(0xFFF5C6B8)),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: AppOpacity.light),
              borderRadius: BorderRadius.circular(AppBorderRadius.xs),
            ),
            alignment: Alignment.center,
            child: Text(
              '#${conflict.bibNumber}',
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(conflict.runnerName, style: AppTypography.smallBodySemibold),
              Text(
                '${conflict.team} · Grade ${conflict.grade}',
                style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 — N>2 occurrence path
// ---------------------------------------------------------------------------

class _MultiOccurrenceStep1 extends StatefulWidget {
  const _MultiOccurrenceStep1({required this.conflict});

  final MockDuplicateConflict conflict;

  @override
  State<_MultiOccurrenceStep1> createState() => _MultiOccurrenceStep1State();
}

class _MultiOccurrenceStep1State extends State<_MultiOccurrenceStep1> {
  int? _selectedPosition;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ConflictResolutionController>();
    final occurrences = widget.conflict.occurrences;
    final leftoverCount = occurrences.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...occurrences.map((o) => _OccurrenceListRow(
              occurrence: o,
              isSelected: _selectedPosition == o.position,
              onSelect: () => setState(() => _selectedPosition = o.position),
              onSeeMore: () => _showNearbySheet(
                context,
                widget.conflict.surroundingFinishers,
                o.position,
                widget.conflict.bibNumber,
                o.formattedTime,
              ),
            )),
        if (_selectedPosition != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.statusSetup.withValues(alpha: AppOpacity.faint),
              border: Border.all(
                color: AppColors.statusSetup.withValues(alpha: AppOpacity.medium),
              ),
              borderRadius: BorderRadius.circular(AppBorderRadius.sm),
            ),
            child: Text(
              'This will add $leftoverCount unknown conflict'
              '${leftoverCount == 1 ? '' : 's'} to resolve next.',
              style: AppTypography.caption.copyWith(color: AppColors.statusSetup),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FullWidthButton(
            text: 'Confirm ${_ordinal(_selectedPosition!)} place is correct →',
            onPressed: () =>
                controller.chooseDuplicateOccurrence(_selectedPosition!),
          ),
        ],
      ],
    );
  }
}

class _OccurrenceListRow extends StatelessWidget {
  const _OccurrenceListRow({
    required this.occurrence,
    required this.isSelected,
    required this.onSelect,
    required this.onSeeMore,
  });

  final ({int position, String formattedTime}) occurrence;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onSeeMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: onSelect,
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppAnimations.fast,
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryColor
                      : AppColors.lightColor,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                _ordinal(occurrence.position),
                style: AppTypography.smallBodySemibold,
              ),
            ),
            Text(
              occurrence.formattedTime,
              style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onSeeMore,
              child: Text(
                'See more ↓',
                style: AppTypography.caption.copyWith(
                  color: AppColors.mediumColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
