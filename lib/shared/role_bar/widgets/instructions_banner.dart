import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:xceleration/core/theme/typography.dart';
import '../../../shared/role_bar/models/role_enums.dart';

/// Banner widget that displays a tappable instructions prompt.
/// Tapping the banner shows a modal sheet with instructions.
class InstructionsBanner extends StatelessWidget {
  final Role currentRole;
  const InstructionsBanner({super.key, required this.currentRole});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8.0),
      onTap: () => showInstructionsSheetManual(context, currentRole),
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            const Icon(Icons.info_outline, color: Colors.blueAccent, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Instructions',
                style: AppTypography.headerRegular,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a modal bottom sheet with placeholder instructions using the shared sheet function and app typography.
  /// Only shows instructions once per role using shared preferences.
  static Future<void> showInstructionsSheet(
      BuildContext context, Role role) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'instructions_shown_${role.name}';
    final hasShownBefore = prefs.getBool(key) ?? false;

    if (!hasShownBefore && context.mounted) {
      await DialogUtils.showMessageDialog(
        context,
        title: 'Instructions',
        message: _getInstructions(role),
        doneText: 'Got it',
        barrierTint: 0.3,
      );

      // Mark instructions as shown for this role
      await prefs.setBool(key, true);
    }
  }

  /// Shows instructions dialog regardless of whether they've been shown before.
  /// This is used when the user manually clicks the instructions button.
  static Future<void> showInstructionsSheetManual(
      BuildContext context, Role role) async {
    if (context.mounted) {
      await DialogUtils.showMessageDialog(
        context,
        title: 'Instructions',
        message: _getInstructions(role),
        doneText: 'Got it',
        barrierTint: 0.3,
      );
    }
  }

  /// Returns the instructions for the given role.
  static String _getInstructions(Role role) {
    switch (role) {
      case Role.bibRecorder:
        return 'You record each runner\'s bib number as they finish, in the '
            'order they cross the line: hold the button and say it, or type '
            'it.\n\nBefore the race, tap Get Race from '
            'Coach so your list knows the runners. When there is a break in '
            'the runners, tell the Timer how many bibs you have.';
      case Role.timer:
        return 'You time the race. Tap Start when the gun goes, and Log as '
            'each runner crosses the finish line. Missed the gun by a few '
            'seconds? That is fine: once the race has started, choose Started '
            'Early or Late? from the menu.\n\nWhen there is a break '
            'in the runners, compare your count with the Bib Recorder\'s. If '
            'they are the same, tap Counts match. If not, tap Counts differ? '
            'and choose what happened.';
      case Role.coach:
        return 'Each race has three steps, shown at the top of it:\n\n'
            '1. Set up: tap + to create the race, then add its teams and '
            'runners.\n'
            '2. Send to volunteers: on race day, send the race to the Timer '
            'and Bib Recorder phones.\n'
            '3. Collect results: after the race, collect their times and '
            'bibs, sort out anything that doesn\'t match, and save.\n\n'
            'Then tap Share Results on the Results tab: as text, a Google '
            'Sheet or a PDF, or to spectators nearby.';
      case Role.spectator:
        return 'You see the results of races a coach shares with you.\n\n'
            'Tap Receive Race, then choose Coach. On the coach\'s '
            'phone, they tap Share Results, then Send to Spectators. You can '
            'also get a race from another spectator who already has it.';
    }
  }
}
