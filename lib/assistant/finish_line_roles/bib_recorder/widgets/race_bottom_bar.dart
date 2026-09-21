import 'package:flutter/material.dart';
import 'package:xceleration/assistant/bib_number_recorder/widgets/runners_loaded_sheet.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/overflow_menu_button.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/race_mode_controls.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/widgets/confirm_bottom_sheet.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';

/// Bottom action bar for the race recording screen.
///
/// Shows a Start Race / Stop Race button and an overflow menu.
class RaceBottomBar extends StatelessWidget {
  const RaceBottomBar({
    super.key,
    required this.isRaceStarted,
    required this.entryCount,
    required this.runners,
    required this.onBeginRace,
    required this.onStopRace,
    required this.onDeleteRace,
    required this.onClearEntries,
    required this.onLeaveRace,
  });

  final bool isRaceStarted;
  final int entryCount;
  final List<Runner> runners;
  final VoidCallback onBeginRace;
  final VoidCallback onStopRace;
  final VoidCallback onDeleteRace;
  final VoidCallback onClearEntries;
  final VoidCallback onLeaveRace;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: isRaceStarted
                ? RaceActionButton(
                    label: 'Stop Race',
                    color: AppColors.redColor,
                    backgroundColor:
                        AppColors.redColor.withValues(alpha: AppOpacity.faint),
                    borderColor:
                        AppColors.redColor.withValues(alpha: AppOpacity.strong),
                    onTap: () => _showStopConfirm(context),
                  )
                : RaceActionButton(
                    label: 'Start Race',
                    color: AppColors.statusFinished,
                    backgroundColor: AppColors.statusFinished
                        .withValues(alpha: AppOpacity.light),
                    borderColor: AppColors.statusFinished,
                    onTap: onBeginRace,
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OverflowMenuButton(
            items: [
              OverflowMenuItem(
                label: 'View Runners',
                onTap: () => sheet(
                  context: context,
                  title: 'Loaded Runners',
                  body: RunnersLoadedSheet(
                    runners: runners
                        .map((r) => BibDatum(
                              bib: r.bibNumber,
                              name: r.name,
                              teamAbbreviation: r.teamAbbreviation,
                              grade: r.grade,
                              teamColor: r.teamColor,
                            ))
                        .toList(),
                  ),
                ),
              ),
              OverflowMenuItem(
                label: 'Clear All Records',
                danger: true,
                onTap: onClearEntries,
              ),
              OverflowMenuItem(
                label: 'Delete Race',
                danger: true,
                onTap: () => _showDeleteConfirm(context),
              ),
              OverflowMenuItem(
                label: 'Leave Race',
                onTap: onLeaveRace,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStopConfirm(BuildContext context) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConfirmBottomSheet(
        title: 'Stop Race?',
        message:
            'Stopping ends recording. You can still edit entries afterward.',
        confirmLabel: 'Stop Race',
        onConfirm: onStopRace,
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConfirmBottomSheet(
        title: 'Delete Race?',
        message: 'Permanently deletes all $entryCount bib records.',
        confirmLabel: 'Delete',
        onConfirm: onDeleteRace,
      ),
    );
  }
}
