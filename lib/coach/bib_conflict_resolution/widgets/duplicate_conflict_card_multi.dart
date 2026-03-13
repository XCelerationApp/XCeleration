part of 'duplicate_conflict_card.dart';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DUPLICATE BIB',
                    style: AppTypography.extraSmall.copyWith(
                      letterSpacing: 0.5,
                      color: AppColors.primaryColor,
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
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.selectedRoleColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: AppColors.primaryColor,
                  size: 22,
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
        Text(
          'Bib #${widget.conflict.bibNumber} was recorded ${widget.conflict.occurrences.length} times. Select the finish time that belongs to this runner.',
          style: AppTypography.bodyRegular.copyWith(color: AppColors.mediumColor),
        ),
        const SizedBox(height: AppSpacing.md),
        // Bounded height so 3+ tiles scroll rather than overflow.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: occurrences
                  .map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _SelectableOccurrenceTile(
                          occurrence: o,
                          conflict: widget.conflict,
                          isSelected: _selectedPosition == o.position,
                          onSelect: () =>
                              setState(() => _selectedPosition = o.position),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        _TipBanner(
          message: '💡 Tap a finish to mark it correct. '
              'The other${leftoverCount == 1 ? '' : 's'} will need '
              '${leftoverCount == 1 ? 'a runner' : 'runners'} assigned.',
        ),
        if (_selectedPosition != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: AppOpacity.faint),
              border: Border.all(
                color: AppColors.primaryColor.withValues(alpha: AppOpacity.medium),
              ),
              borderRadius: BorderRadius.circular(AppBorderRadius.sm),
            ),
            child: Text(
              'This will add $leftoverCount unknown conflict'
              '${leftoverCount == 1 ? '' : 's'} to resolve next.',
              style: AppTypography.caption.copyWith(color: AppColors.primaryColor),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FullWidthButton(
            text: 'Confirm ${ordinal(_selectedPosition!)} place is correct →',
            onPressed: () =>
                controller.chooseDuplicateOccurrence(_selectedPosition!),
          ),
        ],
      ],
    );
  }
}

class _SelectableOccurrenceTile extends StatefulWidget {
  const _SelectableOccurrenceTile({
    required this.occurrence,
    required this.conflict,
    required this.isSelected,
    required this.onSelect,
  });

  final ({int position, String formattedTime}) occurrence;
  final MockDuplicateConflict conflict;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  State<_SelectableOccurrenceTile> createState() =>
      _SelectableOccurrenceTileState();
}

class _SelectableOccurrenceTileState
    extends State<_SelectableOccurrenceTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onSelect,
      child: AnimatedContainer(
        duration: AppAnimations.standard,
        curve: AppAnimations.spring,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
              : _pressed
                  ? AppColors.lightColor.withValues(alpha: AppOpacity.medium)
                  : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primaryColor : AppColors.lightColor,
            width: selected ? 2 : 1,
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
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ordinal(widget.occurrence.position)} place',
                    style: AppTypography.smallBodyRegular.copyWith(
                      color: AppColors.mediumColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.occurrence.formattedTime,
                    style: AppTypography.displaySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => showNearbySheet(
                      context,
                      entries: widget.conflict.surroundingFinishers,
                      conflictPosition: widget.occurrence.position,
                      conflictBib: widget.conflict.bibNumber,
                      conflictTime: widget.occurrence.formattedTime,
                    ),
                    child: Text(
                      'See more ↓',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedScale(
              scale: selected ? 1 : 0,
              duration: AppAnimations.fast,
              curve: AppAnimations.spring,
              child: const Icon(
                Icons.check_circle,
                color: AppColors.primaryColor,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
