part of 'duplicate_conflict_card.dart';

// ---------------------------------------------------------------------------
// Step 1 — 2-occurrence path
// ---------------------------------------------------------------------------

class _TwoOccurrenceStep1 extends StatelessWidget {
  const _TwoOccurrenceStep1({required this.conflict});

  final MockDuplicateConflict conflict;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ConflictResolutionController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TipBanner(),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _OccurrenceTile(
                occurrence: conflict.occurrences[0],
                conflict: conflict,
                onConfirm: () => controller
                    .chooseDuplicateOccurrence(conflict.occurrences[0].position),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _OccurrenceTile(
                occurrence: conflict.occurrences[1],
                conflict: conflict,
                onConfirm: () => controller
                    .chooseDuplicateOccurrence(conflict.occurrences[1].position),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TipBanner extends StatelessWidget {
  const _TipBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          border: Border.all(color: AppColors.borderColor),
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        ),
        child: Text(
          'Tap the position where this runner actually finished.',
          style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
        ),
      );
}

class _OccurrenceTile extends StatefulWidget {
  const _OccurrenceTile({
    required this.occurrence,
    required this.conflict,
    required this.onConfirm,
  });

  final ({int position, String formattedTime}) occurrence;
  final MockDuplicateConflict conflict;
  final VoidCallback onConfirm;

  @override
  State<_OccurrenceTile> createState() => _OccurrenceTileState();
}

class _OccurrenceTileState extends State<_OccurrenceTile> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppAnimations.standard,
      curve: AppAnimations.spring,
      decoration: BoxDecoration(
        color: _confirmed
            ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
            : Colors.white,
        border: Border.all(
          color: _confirmed ? AppColors.primaryColor : AppColors.lightColor,
          width: _confirmed ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _ordinal(widget.occurrence.position),
            style: AppTypography.titleSemibold,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.occurrence.formattedTime,
            style: AppTypography.bodyRegular.copyWith(color: AppColors.mediumColor),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _showNearbySheet(
              context,
              widget.conflict.surroundingFinishers,
              widget.occurrence.position,
              widget.conflict.bibNumber,
              widget.occurrence.formattedTime,
            ),
            child: Text(
              'See more ↓',
              style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_confirmed)
            const Icon(Icons.check_circle, color: AppColors.primaryColor, size: 28)
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _confirmed = true);
                  Future.delayed(AppAnimations.standard, widget.onConfirm);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                ),
                child: Text('This one', style: AppTypography.smallBodySemibold),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nearby Finishers sheet (used by both step 1 "See more ↓" and step 2 link)
// ---------------------------------------------------------------------------

class _NearbyFinishersSheet extends StatelessWidget {
  const _NearbyFinishersSheet({
    required this.entries,
    required this.conflictPosition,
    required this.conflictBib,
    required this.conflictTime,
  });

  final List<MockFinishEntry> entries;
  final int conflictPosition;
  final int conflictBib;
  final String conflictTime;

  @override
  Widget build(BuildContext context) {
    final allRows = <(int, Widget)>[
      for (final e in entries) (e.position, _FinisherRow(entry: e)),
      (
        conflictPosition,
        _ConflictFinisherRow(
          position: conflictPosition,
          bib: conflictBib,
          time: conflictTime,
        ),
      ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: allRows.map((r) => r.$2).toList(),
    );
  }
}

class _FinisherRow extends StatelessWidget {
  const _FinisherRow({required this.entry});

  final MockFinishEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _ordinal(entry.position),
              style: AppTypography.caption.copyWith(
                color: AppColors.mediumColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              entry.runnerName,
              style: AppTypography.smallBodyRegular,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            entry.formattedTime,
            style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
          ),
        ],
      ),
    );
  }
}

class _ConflictFinisherRow extends StatelessWidget {
  const _ConflictFinisherRow({
    required this.position,
    required this.bib,
    required this.time,
  });

  final int position;
  final int bib;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: AppOpacity.faint),
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        border: const Border(
          left: BorderSide(color: AppColors.primaryColor, width: 2),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _ordinal(position),
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Bib #$bib',
              style: AppTypography.smallBodyRegular.copyWith(
                color: AppColors.primaryColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            time,
            style: AppTypography.caption.copyWith(color: AppColors.primaryColor),
          ),
        ],
      ),
    );
  }
}
