import 'package:flutter/material.dart';
import '../mock/conflict_mock_data.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

/// A conflict entry to be shown inline alongside clean finishers.
typedef ConflictEntry = ({int position, String formattedTime, String label});

/// Collapsible panel showing the finishers surrounding a conflict position.
/// Collapsed: one runner ahead, one behind. Expanded: full surrounding window
/// with conflict positions merged in and highlighted.
class RaceContextPanel extends StatelessWidget {
  const RaceContextPanel({
    super.key,
    required this.surroundingFinishers,
    required this.contextPosition,
    this.conflictEntries = const [],
  });

  final List<MockFinishEntry> surroundingFinishers;

  /// The conflict's earliest finish position — used to find the runners ahead/behind.
  final int contextPosition;

  /// The conflict's own finish positions, merged into the full window.
  final List<ConflictEntry> conflictEntries;

  MockFinishEntry? get _ahead => surroundingFinishers
      .where((e) => e.position < contextPosition)
      .lastOrNull;

  MockFinishEntry? get _behind => surroundingFinishers
      .where((e) => e.position > contextPosition)
      .firstOrNull;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.lightColor.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        title: Text(
          'Surrounding finishers',
          style: AppTypography.smallBodySemibold.copyWith(
            color: AppColors.mediumColor,
          ),
        ),
        initiallyExpanded: false,
        children: [
          const Divider(height: 1),
          _DefaultRows(ahead: _ahead, behind: _behind),
          const SizedBox(height: AppSpacing.xs),
          _ExpandedList(
            entries: surroundingFinishers,
            conflictEntries: conflictEntries,
          ),
        ],
      ),
    );
  }
}

class _DefaultRows extends StatelessWidget {
  const _DefaultRows({required this.ahead, required this.behind});

  final MockFinishEntry? ahead;
  final MockFinishEntry? behind;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ContextRow(
          label: 'Ahead',
          entry: ahead,
          icon: Icons.arrow_upward,
        ),
        _ContextRow(
          label: 'Behind',
          entry: behind,
          icon: Icons.arrow_downward,
        ),
      ],
    );
  }
}

class _ExpandedList extends StatelessWidget {
  const _ExpandedList({
    required this.entries,
    required this.conflictEntries,
  });

  final List<MockFinishEntry> entries;
  final List<ConflictEntry> conflictEntries;

  @override
  Widget build(BuildContext context) {
    // Merge clean entries and conflict entries, sorted by position.
    final allRows = <(int, Widget)>[
      for (final e in entries) (e.position, _ContextRow(entry: e)),
      for (final e in conflictEntries)
        (e.position, _ConflictEntryRow(entry: e)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Text(
            'Full window',
            style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
          ),
        ),
        ...allRows.map((r) => r.$2),
      ],
    );
  }
}

String _ordinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  switch (n % 10) {
    case 1: return '${n}st';
    case 2: return '${n}nd';
    case 3: return '${n}rd';
    default: return '${n}th';
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({
    this.label,
    required this.entry,
    this.icon,
  });

  final String? label;
  final MockFinishEntry? entry;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.mediumColor),
            const SizedBox(width: AppSpacing.xs),
          ],
          SizedBox(
            width: 36,
            child: Text(
              entry != null ? _ordinal(entry!.position) : '—',
              style: AppTypography.caption.copyWith(
                color: AppColors.mediumColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              entry?.runnerName ?? '—',
              style: AppTypography.smallBodyRegular,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (entry != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              entry!.formattedTime,
              style: AppTypography.caption.copyWith(
                color: AppColors.mediumColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A highlighted row for a conflict's own finish entry.
class _ConflictEntryRow extends StatelessWidget {
  const _ConflictEntryRow({required this.entry});

  final ConflictEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: AppOpacity.faint),
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        border: Border(
          left: BorderSide(color: AppColors.primaryColor, width: 2),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _ordinal(entry.position),
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              entry.label,
              style: AppTypography.smallBodyRegular.copyWith(
                color: AppColors.primaryColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            entry.formattedTime,
            style: AppTypography.caption.copyWith(
              color: AppColors.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
