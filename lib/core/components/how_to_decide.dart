import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/typography.dart';
import '../utils/sheet_utils.dart';

/// A small "How to decide" link that opens a few short tips, for when the
/// app's own suggestions are not enough to settle a conflict. Kept to a link
/// so the card stays about the conflict itself.
class HowToDecide extends StatelessWidget {
  const HowToDecide({super.key, required this.tips, this.lastResort});

  /// What to try, most useful first.
  final List<String> tips;

  /// What to do when nothing settles it, shown last and set apart.
  final String? lastResort;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const ValueKey('how_to_decide'),
      onPressed: () => sheet(
        context: context,
        title: 'How to Decide',
        body: _Tips(tips: tips, lastResort: lastResort),
      ),
      icon: const Icon(Icons.help_outline, size: 18),
      label: const Text('How to decide'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.mediumColor,
        padding: EdgeInsets.zero,
        textStyle: AppTypography.smallBodySemibold,
      ),
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips({required this.tips, this.lastResort});

  final List<String> tips;
  final String? lastResort;

  @override
  Widget build(BuildContext context) {
    final style =
        AppTypography.bodyRegular.copyWith(color: AppColors.darkColor);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final tip in tips)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: style),
                Expanded(child: Text(tip, style: style)),
              ],
            ),
          ),
        if (lastResort != null)
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.xs),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(lastResort!,
                style: AppTypography.smallBodyRegular
                    .copyWith(color: AppColors.mediumColor)),
          ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// Tips for the conflicts a coach settles after a race.
abstract final class ConflictTips {
  static const duplicateWhichIsTheirs = [
    'Look at the time and the runners around each finish.',
    'Ask the runner, or their teammates, roughly where they finished.',
    'Ask their coach where they usually finish among their teammates.',
  ];

  static const whoWasIt = [
    'The suggestions are bibs one slip of the thumb away (a digit '
        'different, swapped, left out or extra), or in the same team\'s '
        'block of bibs.',
    'Ask the runners who finished around this spot who came in near them.',
    'Ask that team\'s coach or runners who it could be, from the finish '
        'time and who was around them.',
    'Look for who is missing: Find Someone Else only lists runners not in '
        'the results yet.',
  ];

  static const bibLastResort = 'Still not sure? Pick the most likely runner. '
      'You can change any result later with Edit on the Results tab.';

  static const missingTime = [
    'The missed runner is often in the biggest gap between times (the gap '
        'is under each time). Timers often miss one of two runners finishing '
        'together.',
    'Ask the runners in this stretch who finished close together, and how '
        'the finish went. A parent\'s video helps too.',
    'If someone has a backup watch or video, type the time from it.',
  ];

  static const extraTime = [
    'A stray tap is usually right after another time: look for a tiny gap '
        'under a time.',
    'Ask the runners around that time whether anyone finished right then.',
  ];

  static const timeLastResort = 'Nobody remembers? Tap Best Guess. For a '
      'missing time it puts the time halfway across the biggest gap; for an '
      'extra one it removes the time closest to the one before. Everyone '
      'keeps the right place, and times are off by a second or two at most. '
      'Check it, then Resolve. You can change any result later with Edit on '
      'the Results tab.';
}
