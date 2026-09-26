import 'package:flutter/material.dart';

import '../../../core/components/button_components.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../services/roster_update.dart';

/// What updating a team from a spreadsheet will do, listed before anything
/// changes. Pops true when the coach goes ahead.
class RosterUpdatePreview extends StatelessWidget {
  const RosterUpdatePreview({super.key, required this.plan});

  final RosterUpdatePlan plan;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                if (plan.added.isNotEmpty)
                  _Section(
                    icon: Icons.person_add_alt_1_outlined,
                    color: AppColors.statusFinished,
                    title: 'New (${plan.added.length})',
                    lines: [
                      for (final row in plan.added)
                        '${row['name']}  ·  Bib ${row['bib']}  ·  '
                            'Grade ${row['grade']}',
                    ],
                  ),
                if (plan.changed.isNotEmpty)
                  _Section(
                    icon: Icons.edit_outlined,
                    color: AppColors.statusPreRace,
                    title: 'Changed (${plan.changed.length})',
                    lines: [
                      for (final change in plan.changed) _describe(change),
                    ],
                  ),
                if (plan.removed.isNotEmpty)
                  _Section(
                    icon: Icons.person_remove_outlined,
                    color: AppColors.redColor,
                    title: 'Not on the sheet (${plan.removed.length})',
                    note: 'They come off this team and this race. Their '
                        'results from past races are kept.',
                    lines: [
                      for (final runner in plan.removed)
                        '${runner.name}  ·  Bib ${runner.bibNumber}',
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FullWidthButton(
          text: 'Update Team',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }

  static String _describe(RunnerChange change) {
    final before = change.before, after = change.after;
    final parts = <String>[
      if (before.name != after.name) '${before.name} → ${after.name}',
      if (before.bibNumber != after.bibNumber)
        'Bib ${before.bibNumber} → ${after.bibNumber}',
      if (before.grade != after.grade)
        'Grade ${before.grade} → ${after.grade}',
    ];
    final who = before.name == after.name ? '${after.name}: ' : '';
    return '$who${parts.join(', ')}';
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.color,
    required this.title,
    required this.lines,
    this.note,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<String> lines;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(title,
                  style: AppTypography.bodySemibold.copyWith(color: color)),
            ],
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(note!,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.mediumColor)),
            ),
          const SizedBox(height: AppSpacing.xs),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(line, style: AppTypography.bodyRegular),
            ),
        ],
      ),
    );
  }
}
