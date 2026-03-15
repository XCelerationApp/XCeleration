import 'package:flutter/material.dart';
import '../mock/conflict_mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/sheet_utils.dart';
import '../utils/ordinal.dart';

/// Opens the "Around Nth place" bottom sheet showing nearby finishers
/// alongside the highlighted conflict row.
///
/// Uses a custom sheet layout so that horizontal padding is applied only to
/// the header — the body rows manage their own padding, which lets the
/// conflict row fill edge-to-edge without any layout tricks.
void showNearbySheet(
  BuildContext context, {
  required List<MockFinishEntry> entries,
  required int conflictPosition,
  required int conflictBib,
  required String conflictTime,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  showModalBottomSheet<void>(
    backgroundColor: Colors.transparent,
    context: context,
    isScrollControlled: true,
    enableDrag: true,
    builder: (ctx) {
      final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.92,
        ),
        child: Padding(
          padding: EdgeInsets.only(top: 8, bottom: bottomInset + 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: createSheetHeader(
                  'Around ${ordinal(conflictPosition)} place',
                ),
              ),
              Flexible(
                child: NearbyFinishersSheet(
                  entries: entries,
                  conflictPosition: conflictPosition,
                  conflictBib: conflictBib,
                  conflictTime: conflictTime,
                ),
              ),
            ],
          ),
        ),
      );
    },
  ).then((_) => FocusManager.instance.primaryFocus?.unfocus());
}

/// Scrollable list of finishers surrounding a conflict position.
/// The conflict's own row is highlighted with a full-width salmon background.
class NearbyFinishersSheet extends StatelessWidget {
  const NearbyFinishersSheet({
    super.key,
    required this.entries,
    required this.conflictPosition,
    required this.conflictBib,
    required this.conflictTime,
  });

  final List<MockFinishEntry> entries;
  final int conflictPosition;
  final int conflictBib;
  final String conflictTime;

  static const _windowSize = 4;

  @override
  Widget build(BuildContext context) {
    // Take the 4 closest entries above and 4 closest below the conflict position.
    final above = (entries.where((e) => e.position < conflictPosition).toList()
          ..sort((a, b) => b.position.compareTo(a.position)))
        .take(_windowSize)
        .toList()
        .reversed
        .toList();
    final below = (entries.where((e) => e.position > conflictPosition).toList()
          ..sort((a, b) => a.position.compareTo(b.position)))
        .take(_windowSize)
        .toList();

    final allRows = <(int, Widget)>[
      for (final e in [...above, ...below]) (e.position, _FinisherRow(entry: e)),
      (
        conflictPosition,
        _ConflictFinisherRow(
          position: conflictPosition,
          bib: conflictBib,
          time: conflictTime,
        ),
      ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    final widgets = <Widget>[];
    for (int i = 0; i < allRows.length; i++) {
      widgets.add(
        _AnimatedListItem(
          index: i,
          child: allRows[i].$2,
        ),
      );
      if (i < allRows.length - 1) {
        widgets.add(Divider(height: 1, thickness: 1, color: AppColors.lightColor));
      }
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widgets,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animation
// ---------------------------------------------------------------------------

class _AnimatedListItem extends StatefulWidget {
  const _AnimatedListItem({required this.child, required this.index});

  final Widget child;
  final int index;

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: AppAnimations.reveal,
      curve: AppAnimations.enter,
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Row widgets
// ---------------------------------------------------------------------------

class _FinisherRow extends StatelessWidget {
  const _FinisherRow({required this.entry});

  final MockFinishEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.xl,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              ordinal(entry.position),
              style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.runnerName, style: AppTypography.smallBodySemibold),
                Text(
                  entry.team,
                  style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.formattedTime,
                style: AppTypography.smallBodySemibold.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '#${entry.bibNumber}',
                style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
              ),
            ],
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
      color: AppColors.selectedRoleColor,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.xl,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              ordinal(position),
              style: AppTypography.captionBold.copyWith(
                color: AppColors.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unknown runner', style: AppTypography.smallBodySemibold),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: AppTypography.smallBodySemibold.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '#$bib',
                style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
