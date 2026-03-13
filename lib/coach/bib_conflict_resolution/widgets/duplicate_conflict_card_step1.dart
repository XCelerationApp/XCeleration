part of 'duplicate_conflict_card.dart';

// ---------------------------------------------------------------------------
// Step 1 — 2-occurrence path
// ---------------------------------------------------------------------------

class _TwoOccurrenceStep1 extends StatefulWidget {
  const _TwoOccurrenceStep1({required this.conflict});

  final MockDuplicateConflict conflict;

  @override
  State<_TwoOccurrenceStep1> createState() => _TwoOccurrenceStep1State();
}

class _TwoOccurrenceStep1State extends State<_TwoOccurrenceStep1> {
  int? _confirmedPosition;

  @override
  Widget build(BuildContext context) {
    if (_confirmedPosition != null) {
      final leftover = widget.conflict.occurrences
          .firstWhere((o) => o.position != _confirmedPosition);
      return _InlineLeftoverAssignment(
        confirmedPosition: _confirmedPosition!,
        leftoverOccurrence: leftover,
        conflict: widget.conflict,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bib #${widget.conflict.bibNumber} was recorded ${widget.conflict.occurrences.length} times. Select the finish time that belongs to this runner.',
          style: AppTypography.bodyRegular.copyWith(color: AppColors.mediumColor),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _OccurrenceTile(
                occurrence: widget.conflict.occurrences[0],
                conflict: widget.conflict,
                onConfirm: () => setState(
                  () => _confirmedPosition = widget.conflict.occurrences[0].position,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _OccurrenceTile(
                occurrence: widget.conflict.occurrences[1],
                conflict: widget.conflict,
                onConfirm: () => setState(
                  () => _confirmedPosition = widget.conflict.occurrences[1].position,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _TipBanner(),
      ],
    );
  }
}

class _TipBanner extends StatelessWidget {
  const _TipBanner({this.message});

  /// Defaults to the 2-occurrence copy. Pass a custom string for other contexts.
  final String? message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          border: Border.all(color: AppColors.borderColor),
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        ),
        child: Text(
          message ??
              '💡 Tap a finish to mark it correct. The other will need a runner assigned.',
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
    return GestureDetector(
      onTap: _confirmed
          ? null
          : () {
              setState(() => _confirmed = true);
              Future.delayed(AppAnimations.standard, widget.onConfirm);
            },
      child: AnimatedContainer(
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
            if (_confirmed) ...[
              const SizedBox(height: AppSpacing.sm),
              const Icon(Icons.check_circle, color: AppColors.primaryColor, size: 28),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 — inline leftover assignment (2-occ path only)
// ---------------------------------------------------------------------------

class _InlineLeftoverAssignment extends StatefulWidget {
  const _InlineLeftoverAssignment({
    required this.confirmedPosition,
    required this.leftoverOccurrence,
    required this.conflict,
  });

  final int confirmedPosition;
  final ({int position, String formattedTime}) leftoverOccurrence;
  final MockDuplicateConflict conflict;

  @override
  State<_InlineLeftoverAssignment> createState() =>
      _InlineLeftoverAssignmentState();
}

class _InlineLeftoverAssignmentState extends State<_InlineLeftoverAssignment> {
  bool _assignMode = false;

  String get _conflictLabel =>
      '${ordinal(widget.leftoverOccurrence.position)} place '
      '(Bib #${widget.conflict.bibNumber})';

  @override
  Widget build(BuildContext context) {
    final leftover = widget.leftoverOccurrence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Confirmation banner
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withValues(alpha: AppOpacity.faint),
            borderRadius: BorderRadius.circular(AppBorderRadius.sm),
          ),
          child: Row(
            children: [
              const Icon(Icons.check, color: Color(0xFF4CAF50), size: 16),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${ordinal(widget.confirmedPosition)} place is correct',
                style: AppTypography.smallBodySemibold.copyWith(
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Section header
        Text(
          'Who finished ${ordinal(leftover.position)}?',
          style: AppTypography.titleSemibold,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${leftover.formattedTime} · Bib #${widget.conflict.bibNumber} was a typo here',
          style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
        ),
        const SizedBox(height: AppSpacing.md),
        // Nearby context
        InlineContextPanel(
          surroundingFinishers: widget.conflict.surroundingFinishers,
          contextPosition: leftover.position,
        ),
        TextButton(
          onPressed: () => showNearbySheet(
            context,
            entries: widget.conflict.surroundingFinishers,
            conflictPosition: leftover.position,
            conflictBib: widget.conflict.bibNumber,
            conflictTime: leftover.formattedTime,
          ),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          child: Text(
            'See nearby finishers ↓',
            style: AppTypography.caption.copyWith(color: AppColors.primaryColor),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSize(
          duration: AppAnimations.standard,
          curve: AppAnimations.spring,
          child: _assignMode
              ? _DupAssignPanel(
                  targetBib: widget.conflict.bibNumber,
                  conflictLabel: _conflictLabel,
                  onDismiss: () => setState(() => _assignMode = false),
                )
              : _DupActionButtons(
                  onAssign: () => setState(() => _assignMode = true),
                  onCreate: () => _openCreateSheet(context),
                ),
        ),
      ],
    );
  }

  Future<void> _openCreateSheet(BuildContext context) async {
    final controller = context.read<ConflictResolutionController>();
    await sheet(
      context: context,
      title: 'Add New Runner',
      body: MockCreateRunnerSheet(
        allKnownBibs: controller.allKnownBibs,
        teams: controller.teams,
        forbiddenBib: widget.conflict.bibNumber,
        onCreated: (name, bib, team, grade) {
          controller.prepareCreateForDuplicate(
            name,
            bib,
            team,
            grade,
            _conflictLabel,
          );
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _DupAssignPanel extends StatelessWidget {
  const _DupAssignPanel({
    required this.targetBib,
    required this.conflictLabel,
    required this.onDismiss,
  });

  final int targetBib;
  final String conflictLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ConflictResolutionController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Assign Existing Runner', style: AppTypography.smallBodySemibold),
            const Spacer(),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close, size: 20, color: AppColors.mediumColor),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        RunnerAssignmentList(
          targetBib: targetBib,
          forbiddenBib: targetBib,
          onAssign: (runner, _) =>
              controller.prepareAssignForDuplicate(runner, conflictLabel),
        ),
      ],
    );
  }
}

class _DupActionButtons extends StatelessWidget {
  const _DupActionButtons({required this.onAssign, required this.onCreate});

  final VoidCallback onAssign;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: onAssign,
          icon: const Icon(Icons.person_outline, size: 18),
          label: const Text('Assign Existing Runner'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryColor,
            backgroundColor: AppColors.selectedRoleColor,
            side: const BorderSide(color: AppColors.primaryColor),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ElevatedButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Create New Runner'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            ),
          ),
        ),
      ],
    );
  }
}

