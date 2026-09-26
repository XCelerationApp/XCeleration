part of 'duplicate_conflict_card.dart';

// ---------------------------------------------------------------------------
// Step 1 — 2-occurrence path
// ---------------------------------------------------------------------------

class _TwoOccurrenceStep1 extends StatelessWidget {
  const _TwoOccurrenceStep1({required this.conflict});

  final DuplicateBibConflict conflict;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ConflictResolutionController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bib #${conflict.bibNumber} was typed at two finishes. Which one '
          'was ${conflict.runner.runner.name ?? 'this runner'}? The other '
          'was a typo for someone else.',
          style: AppTypography.bodyRegular.copyWith(color: AppColors.mediumColor),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _OccurrenceTile(
                occurrence: conflict.occurrences[0],
                conflict: conflict,
                onConfirm: () => controller
                    .chooseDuplicateOccurrence(conflict.occurrences[0].place),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _OccurrenceTile(
                occurrence: conflict.occurrences[1],
                conflict: conflict,
                onConfirm: () => controller
                    .chooseDuplicateOccurrence(conflict.occurrences[1].place),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _TipBanner(),
        const HowToDecide(
          tips: ConflictTips.duplicateWhichIsTheirs,
          lastResort: ConflictTips.bibLastResort,
        ),
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

  final ConflictOccurrence occurrence;
  final DuplicateBibConflict conflict;
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
              '${ordinal(widget.occurrence.place)} place',
              style: AppTypography.smallBodyRegular.copyWith(
                color: AppColors.mediumColor,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // A range while the time itself is still in question.
            if (widget.occurrence.timeLabel != null)
              Text(
                widget.occurrence.timeLabel!,
                style: widget.occurrence.time != null
                    ? AppTypography.displaySmall
                    : AppTypography.bodyRegular
                        .copyWith(color: AppColors.mediumColor),
                textAlign: TextAlign.center,
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
                entries: widget.occurrence.nearby,
                allFinishers: widget.occurrence.allFinishers,
                conflictPosition: widget.occurrence.place,
                conflictBib: widget.conflict.bibNumber,
                conflictTime: widget.occurrence.time,
                conflictLabel: 'Is this ${widget.conflict.runner.runner.name ?? 'them'}?',
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
// Step 2 — who each of the other finishes was, one at a time
// ---------------------------------------------------------------------------

class _InlineLeftoverAssignment extends StatefulWidget {
  const _InlineLeftoverAssignment({
    required this.confirmedPosition,
    required this.leftoverOccurrence,
    required this.leftoversRemaining,
    required this.conflict,
  });

  final int confirmedPosition;
  final ConflictOccurrence leftoverOccurrence;

  /// How many of the bib's other finishes still need a runner, this one
  /// included.
  final int leftoversRemaining;
  final DuplicateBibConflict conflict;

  @override
  State<_InlineLeftoverAssignment> createState() =>
      _InlineLeftoverAssignmentState();
}

class _InlineLeftoverAssignmentState extends State<_InlineLeftoverAssignment> {
  String get _conflictLabel =>
      '${ordinal(widget.leftoverOccurrence.place)} place '
      '(Bib #${widget.conflict.bibNumber})';

  @override
  Widget build(BuildContext context) {
    final leftover = widget.leftoverOccurrence;
    final suggestions = context
        .watch<ConflictResolutionController>()
        .suggestionsFor(widget.conflict.bibNumber);

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
              // Flexible so a narrow screen or large text wraps it instead of
              // overflowing the banner.
              Flexible(
                child: Text(
                  '${ordinal(widget.confirmedPosition)} place is correct',
                  style: AppTypography.smallBodySemibold.copyWith(
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Section header
        Text(
          'Who finished ${ordinal(leftover.place)}?',
          style: AppTypography.titleSemibold,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          [
            ?leftover.time,
            'Bib #${widget.conflict.bibNumber} was a typo here',
            if (widget.leftoversRemaining > 1)
              '${widget.leftoversRemaining} finishes left',
          ].join(' · '),
          style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
        ),
        const SizedBox(height: AppSpacing.md),
        // Nearby context
        InlineContextPanel(
          surroundingFinishers: leftover.nearby,
          contextPosition: leftover.place,
          conflictBib: widget.conflict.bibNumber,
          conflictTime: leftover.time,
        ),
        TextButton(
          onPressed: () => showNearbySheet(
            context,
            entries: leftover.nearby,
            allFinishers: leftover.allFinishers,
            conflictPosition: leftover.place,
            conflictBib: widget.conflict.bibNumber,
            conflictTime: leftover.time,
          ),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          child: Text(
            'See nearby finishers ↓',
            style: AppTypography.caption.copyWith(color: AppColors.primaryColor),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // The bib was typed for someone else here: whose bib is one slip
        // from it, or among the same team's bibs?
        SuggestedRunners(
          suggestions: suggestions,
          onPick: (runner) => context
              .read<ConflictResolutionController>()
              .prepareAssignForDuplicate(runner, _conflictLabel),
        ),
        if (suggestions.isNotEmpty) const SizedBox(height: AppSpacing.sm),
        // Find Runner: search the roster, or create the runner if they are
        // not on it. The fallback once the app has made its best guesses.
        suggestions.isEmpty
            ? PrimaryButton(
                text: 'Find Runner',
                icon: Icons.search,
                size: ButtonSize.fullWidth,
                onPressed: () => _openFindSheet(context),
              )
            : SecondaryButton(
                text: 'Find Someone Else',
                icon: Icons.search,
                size: ButtonSize.fullWidth,
                onPressed: () => _openFindSheet(context),
              ),
        const HowToDecide(
          tips: ConflictTips.whoWasIt,
          lastResort: ConflictTips.bibLastResort,
        ),
      ],
    );
  }

  Future<void> _openFindSheet(BuildContext context) async {
    final controller = context.read<ConflictResolutionController>();
    RaceRunner? pendingRunner;
    String? newRunnerName;

    await sheet(
      context: context,
      title: 'Find Runner',
      body: ChangeNotifierProvider.value(
        value: controller,
        child: RunnerAssignmentList(
          targetBib: widget.conflict.bibNumber,
          forbiddenBib: widget.conflict.bibNumber,
          onAssign: (runner, _) {
            pendingRunner = runner;
            Navigator.of(context).pop();
          },
          onCreateNew: (name) {
            newRunnerName = name;
            Navigator.of(context).pop();
          },
        ),
      ),
    );

    if (pendingRunner != null) {
      controller.prepareAssignForDuplicate(pendingRunner!, _conflictLabel);
    } else if (newRunnerName != null && context.mounted) {
      await _openCreateSheet(context, name: newRunnerName!);
    }
  }

  Future<void> _openCreateSheet(BuildContext context,
      {required String name}) async {
    final controller = context.read<ConflictResolutionController>();
    await sheet(
      context: context,
      title: 'Add New Runner',
      body: CreateRunnerSheet(
        allKnownBibs: controller.allKnownBibs,
        teams: controller.teams,
        forbiddenBib: widget.conflict.bibNumber,
        // The recorded bib is someone else's, so a free one, changeable.
        autoBib: controller.nextFreeBib,
        initialName: name,
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


