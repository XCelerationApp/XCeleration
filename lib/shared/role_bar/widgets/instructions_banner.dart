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
        return 'You record runners bib numbers during the race after they have passed the finish line.\n\nBefore the race begins, you will need the Coach to share the runners with you.';
      case Role.timer:
        return 'You time the race. Click start when the race begins, and log times when runners cross the finish line.\n\nWhen there is a break in the runners, check with the Bib Recorder to check that your records are the same number. Adjust if needed.';
      case Role.coach:
        return 'You create and manage the races. You will oversee your assistants and will compile and share the race results.';
    }
  }
}
