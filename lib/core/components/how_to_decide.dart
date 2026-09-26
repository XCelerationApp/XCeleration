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
    // Scrolls: on a small phone, or with large text, the tips are taller
    // than the sheet.
    return SingleChildScrollView(
      child: Column(
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
      ),
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
      'It is easiest to get right now, while people remember; if something '
      'turns up later, you can still fix it with Edit on the Results tab.';

  /// For a missing time, with the places the batch covers, e.g. "14th to
  /// 20th".
  static List<String> missingTime(String places) => [
        'Ask the runners from $places who finished right in front of them. '
            '"Was anyone right in front of you, within a second or so?" is '
            'easy to answer. If a runner remembers someone right in front of '
            'them but the times show a big gap there, you\'ve found where the '
            'times don\'t match the finish.',
        'Don\'t go by the gaps alone. A missed runner could be anywhere in '
            'these places, not only in a big gap or a close pair.',
        'A parent\'s finish-line video, a backup watch, or someone else\'s '
            'times for these places settles it, and gives you the time to '
            'type in.',
      ];

  /// For an extra time, with the places the batch covers, e.g. "14th to
  /// 20th".
  static List<String> extraTime(String places) => [
        'Ask the runners from $places how close they finished to the runner '
            'ahead. "Was anyone within half a second in front of you?" is '
            'easy to answer.',
        'Start with the times closest together. A stray tap usually comes '
            'right after a real one, but not always.',
        'A parent\'s finish-line video, or someone else\'s times for these '
            'places, settles it.',
      ];

  static const extraLastResort = 'Nobody can tell? Remove the second of the '
      'two closest times, the most common stray tap. Everyone keeps the right '
      'place; if it was the wrong one, only the runners between it and the '
      'real stray tap get a neighbour\'s time. It\'s easiest to get right '
      'now, but you can still fix it later with Edit on the Results tab.';

  static const missingLastResort = 'Nobody remembers? Put the missing time '
      'where it seems most likely, and type a time between the runners either '
      'side. Everyone keeps the right place. It\'s easiest to get right now, '
      'but you can still fix it later with Edit on the Results tab.';
}
