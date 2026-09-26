import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/enums.dart';
import '../controller/merge_conflicts_controller.dart';
import 'runner_time_record.dart';
import 'header_widgets.dart';
import 'resolve_conflict_button.dart';
import 'undo_button.dart';
import '../utils/timing_suggestions.dart';
import '../../bib_conflict_resolution/utils/ordinal.dart';
import '../../../core/utils/time_formatter.dart';
import 'package:xceleration/coach/merge_conflicts/models/ui_chunk.dart';

class ChunkList extends StatelessWidget {
  const ChunkList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MergeConflictsController>(
      builder: (context, controller, _) {
        final chunks = controller.uiChunks;
        final firstOpen = chunks.indexWhere((c) =>
            c.conflict.type == ConflictType.extraTime ||
            c.conflict.type == ConflictType.missingTime);
        return ListView.builder(
          shrinkWrap: true,
          // Nested in the screen's scroll view: no safe-area inset of its own.
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: chunks.length,
          itemBuilder: (context, index) => ChunkItem(
            key: ValueKey(chunks[index].chunkId),
            index: index,
            chunk: chunks[index],
            controller: controller,
            isFirstOpen: index == firstOpen,
          ),
        );
      },
    );
  }
}

class ChunkItem extends StatefulWidget {
  const ChunkItem({
    super.key,
    required this.index,
    required this.chunk,
    required this.controller,
    this.isFirstOpen = false,
  });
  final int index;
  final UIChunk chunk;
  final MergeConflictsController controller;

  /// Whether this is the first conflict still to resolve. It is scrolled
  /// into view, on opening and after the one before it is resolved: the
  /// page used to open on the first group of confirmed times, with the
  /// conflict somewhere below.
  final bool isFirstOpen;

  @override
  State<ChunkItem> createState() => _ChunkItemState();
}

class _ChunkItemState extends State<ChunkItem> {
  @override
  void initState() {
    super.initState();
    if (widget.isFirstOpen) _scrollIntoView();
  }

  @override
  void didUpdateWidget(ChunkItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFirstOpen && !oldWidget.isFirstOpen) _scrollIntoView();
  }

  void _scrollIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: AppAnimations.standard,
        curve: Curves.easeOut,
        alignment: 0.02,
      );
    });
  }

  int? get _firstPlace {
    for (final r in widget.chunk.records) {
      if (r.place != null) return r.place;
    }
    return null;
  }

  int? get _lastPlace {
    for (final r in widget.chunk.records.reversed) {
      if (r.place != null) return r.place;
    }
    return null;
  }

  /// What the app can say about where the problem is, in a coach's words.
  String? _suggestionText(TimingSpot? spot) {
    if (spot == null || widget.chunk.isResolvedLocally) return null;
    final records = widget.chunk.records;
    final gap = describeGap(spot.gap);
    if (widget.chunk.conflict.type == ConflictType.extraTime) {
      if (spot.row >= records.length) return null;
      final time = records[spot.row].time;
      return spot.clear
          ? '$time is only $gap after the time before it, like a double '
              'tap. Check it first.'
          : 'No time stands out: the closest two are $gap apart. Ask the '
              'runners around this stretch.';
    }
    // A missed runner could be anywhere in the batch, so this says only
    // where Best Guess would put them, and why there.
    final place = spot.row < records.length ? records[spot.row].place : null;
    final where = place != null
        ? 'just before ${ordinal(place)} place'
        : 'after the last time';
    final several = records.where((r) => r.isUnfilled).length > 1;
    // The last batch has no time the missed runner must come before: they
    // may have finished after every time the Timer has.
    final openEnded = !TimeFormatter.isDuration(widget.chunk.endTime);
    return 'Nobody remembers? Best Guess puts ${several ? 'one' : 'it'} in '
        'the biggest gap ($gap, $where), where a guess changes the results '
        'the least.'
        '${openEnded ? ' The runner may also have finished after the last '
            'time; Best Guess can\'t guess a time there.' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final chunkType = widget.chunk.conflict.type;
    final previousChunkEndTime =
        widget.controller.previousEndTimeFor(widget.chunk.chunkId);
    final undoLabel = widget.controller.undoLabel(widget.chunk.chunkId);
    final spot = widget.controller.suggestionFor(widget.chunk.chunkId);

    return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (chunkType == ConflictType.extraTime ||
                chunkType == ConflictType.missingTime)
              ConflictHeader(
                type: chunkType,
                startTime: previousChunkEndTime,
                endTime: widget.chunk.endTime,
                offBy: widget.chunk.conflict.offBy,
                removedCount: widget.chunk.removedCount,
                enteredCount: widget.chunk.enteredCount,
                firstPlace: _firstPlace,
                lastPlace: _lastPlace,
                suggestion: _suggestionText(spot),
                onBestGuess: spot == null || widget.chunk.isResolvedLocally
                    ? null
                    : () => widget.controller.bestGuess(widget.chunk.chunkId),
              ),
            if (chunkType == ConflictType.confirmRunner)
              ConfirmHeader(confirmTime: widget.chunk.endTime),
            const SizedBox(height: 8),
            ...widget.chunk.records.asMap().entries.map<Widget>((entry) {
              return RunnerTimeRecord(
                record: entry.value,
                chunk: widget.chunk,
                controller: widget.controller,
                chunkIndex: entry.key,
              );
            }),
            // Add resolve button for unresolved conflict types
            if (chunkType == ConflictType.extraTime ||
                chunkType == ConflictType.missingTime)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    // Slides in the first time there is something to take
                    // back, rather than jumping the resolve button sideways.
                    AnimatedSize(
                      duration: AppAnimations.fast,
                      curve: AppAnimations.spring,
                      child: undoLabel == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding:
                                  const EdgeInsets.only(right: AppSpacing.sm),
                              child: UndoButton(
                                label: undoLabel,
                                onUndo: () => widget.controller
                                    .undo(widget.chunk.chunkId),
                              ),
                            ),
                    ),
                    Expanded(
                      child: ResolveConflictButton(
                        isResolved: widget.chunk.isResolvedLocally,
                        onResolve: () async {
                          if (chunkType == ConflictType.extraTime) {
                            await widget.controller
                                .resolveExtraTimeConflict(widget.chunk.chunkId);
                          } else if (chunkType == ConflictType.missingTime) {
                            await widget.controller.resolveMissingTimeConflict(
                                widget.chunk.chunkId);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ));
  }
}
