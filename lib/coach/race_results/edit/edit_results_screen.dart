import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/components/dialog_utils.dart';
import '../../../core/components/primary_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../shared/models/database/master_race.dart';
import '../../bib_conflict_resolution/utils/ordinal.dart';
import 'edit_results_controller.dart';
import 'edit_results_sheets.dart';

/// The finish order of a finished race, for correcting who finished where,
/// their times, and finishes that should not count.
class EditResultsScreen extends StatelessWidget {
  const EditResultsScreen({super.key, required this.create});

  final EditResultsController Function() create;

  /// Opens the editor for [masterRace]'s results. Returns whether anything
  /// was saved.
  static Future<bool> open(BuildContext context, MasterRace masterRace) async {
    final results = await masterRace.results;
    final runners = await masterRace.raceRunners;
    if (!context.mounted) return false;
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EditResultsScreen(
          create: () => EditResultsController(
            raceId: masterRace.raceId,
            results: results,
            raceRunners: runners,
            save: masterRace.saveResults,
          ),
        ),
      ),
    );
    return saved ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => create(),
      child: const _EditResultsBody(),
    );
  }
}

class _EditResultsBody extends StatelessWidget {
  const _EditResultsBody();

  Future<void> _leave(BuildContext context) async {
    final c = context.read<EditResultsController>();
    if (c.hasChanges) {
      final discard = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Discard Changes?',
        content: 'Your changes to the results have not been saved.',
        confirmText: 'Discard',
        cancelText: 'Keep Editing',
      );
      if (!discard || !context.mounted) return;
    }
    Navigator.of(context).pop(false);
  }

  Future<void> _save(BuildContext context) async {
    final c = context.read<EditResultsController>();
    if (await c.save() && context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<EditResultsController>();
    return PopScope(
      canPop: !c.hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor,
          // The app's AppBar theme is white-on-orange; this one is light.
          foregroundColor: AppColors.darkColor,
          title: Text('Edit Results',
              style: AppTypography.titleSemibold
                  .copyWith(color: AppColors.darkColor)),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _leave(context),
          ),
          actions: [
            if (c.undoLabel != null)
              TextButton.icon(
                onPressed: c.undo,
                icon: const Icon(Icons.undo),
                label: const Text('Undo'),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                child: Text(
                  'Tap a finish to change the runner or time, or take it out '
                  'of the results.',
                  style: AppTypography.bodyRegular
                      .copyWith(color: AppColors.mediumColor),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: c.finishes.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _FinishRow(
                    place: i + 1,
                    finish: c.finishes[i],
                    onTap: () => _showActions(context, i),
                  ),
                ),
              ),
              if (c.error != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Text(c.error!.userMessage,
                      style: AppTypography.bodyRegular
                          .copyWith(color: AppColors.redColor)),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: FullWidthButton(
                  text: c.isSaving ? 'Saving…' : 'Save Changes',
                  isEnabled: c.hasChanges && !c.isSaving,
                  onPressed: c.hasChanges && !c.isSaving
                      ? () => _save(context)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context, int index) {
    final c = context.read<EditResultsController>();
    final finish = c.finishes[index];
    final place = ordinal(index + 1);
    sheet(
      context: context,
      title: '$place · ${finish.runner.runner.name}',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person_search),
            title: const Text('Change Runner'),
            onTap: () {
              Navigator.of(context).pop();
              sheet(
                context: context,
                title: 'Who finished $place?',
                body: RunnerPicker(
                  runners: c.raceRunners,
                  placeOf: c.placeOf,
                  onPicked: (runner) {
                    c.assignRunner(index, runner);
                    Navigator.of(context).pop();
                  },
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Change Time'),
            onTap: () {
              Navigator.of(context).pop();
              sheet(
                context: context,
                title: 'Time for $place',
                body: TimeEntry(
                  initial: finish.time,
                  onSubmit: (time) => c.changeTime(index, time),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.remove_circle_outline,
                color: AppColors.redColor),
            title: const Text('Take Out of Results',
                style: TextStyle(color: AppColors.redColor)),
            subtitle: const Text('For a disqualification, or someone recorded '
                'who did not finish. Everyone after moves up a place.'),
            onTap: () {
              c.remove(index);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _FinishRow extends StatelessWidget {
  const _FinishRow({
    required this.place,
    required this.finish,
    required this.onTap,
  });

  final int place;
  final EditableFinish finish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final runner = finish.runner;
    return ListTile(
      onTap: onTap,
      leading: SizedBox(
        width: AppSpacing.xxxl,
        child: Text(ordinal(place), style: AppTypography.bodySemibold),
      ),
      title: Text(runner.runner.name ?? 'Unnamed runner',
          style: AppTypography.bodyRegular),
      subtitle: Text(
        '${runner.team.name ?? ''} · #${runner.runner.bibNumber}',
        style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
      ),
      trailing: Text(TimeFormatter.formatDuration(finish.time),
          style: AppTypography.bodySemibold.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()])),
    );
  }
}
