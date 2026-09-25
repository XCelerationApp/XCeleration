import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/components/button_components.dart';
import '../../../core/components/dialog_utils.dart';
import '../services/demo_race_generator.dart';
import '../../../core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:xceleration/core/result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/enums.dart';
import '../models/race_record.dart';
import '../services/assistant_storage_service.dart';

class RaceHeaderWidget extends StatelessWidget {
  final RaceRecord? currentRace;
  final DeviceName role;
  final VoidCallback? onLoadRace;
  final VoidCallback? onShowOtherRaces;
  final VoidCallback? onDeleteRace;
  final VoidCallback? onShowRunners;
  final VoidCallback? onDownloadRace;

  /// Clears what has been recorded for this race. It sits in the menu, away
  /// from the Share button it used to be next to.
  final VoidCallback? onClearRecords;

  /// The menu label for [onClearRecords], such as 'Clear Times'.
  final String clearRecordsLabel;

  /// Whether there is anything to clear, checked when the menu opens.
  final bool Function()? canClearRecords;

  /// While the race runs, the header shrinks to one slim line and the
  /// practice banner becomes a small tag, leaving the room for the race.
  final bool compact;

  const RaceHeaderWidget({
    super.key,
    required this.currentRace,
    required this.role,
    this.onLoadRace,
    this.onShowOtherRaces,
    this.onDeleteRace,
    this.onShowRunners,
    this.onDownloadRace,
    this.onClearRecords,
    this.clearRecordsLabel = 'Clear',
    this.canClearRecords,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 4 : 8),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            if (currentRace != null) _RaceNotifier(currentRace!),
          ]),
          builder: (context, child) {
            if (currentRace == null) {
              return _buildNoRaceBanner(context);
            }
            // The practice race opens by default, and nothing said it was
            // not the real one.
            if (!compact &&
                onLoadRace != null &&
                DemoRaceGenerator.isDemoRace(currentRace!)) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildRaceHeader(context),
                  const SizedBox(height: AppSpacing.sm),
                  _PracticeRaceBanner(onGetRace: onLoadRace!),
                ],
              );
            }
            return _buildRaceHeader(context);
          },
        ));
  }

  Widget _buildNoRaceBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No race yet',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.mediumColor,
              ),
            ),
          ),
          if (onLoadRace != null)
            ElevatedButton(
              onPressed: onLoadRace,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor.withValues(alpha: 0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              ),
              child: Text(
                'Get Race from Coach',
                style: AppTypography.smallBodySemibold.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRaceHeader(BuildContext context) {
    final isPractice = DemoRaceGenerator.isDemoRace(currentRace!);
    return Container(
      padding: EdgeInsets.fromLTRB(16, compact ? 2 : 6, 4, compact ? 2 : 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.lightColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.flag,
            color: AppColors.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              currentRace!.formattedTitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.darkColor,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (compact && isPractice) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryColor
                    .withValues(alpha: AppOpacity.light),
                borderRadius: BorderRadius.circular(AppBorderRadius.full),
              ),
              child: Text('Practice',
                  style: AppTypography.captionBold
                      .copyWith(color: AppColors.primaryColor)),
            ),
          ],
          const SizedBox(width: 4),
          FutureBuilder<List<dynamic>>(
            future: _getOtherRaces(),
            builder: (context, snapshot) {
              final hasOtherRaces = snapshot.hasData &&
                  snapshot.data!.isNotEmpty &&
                  snapshot.data!.length > 1;

              return PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: AppColors.mediumColor,
                  size: 20,
                ),
                onSelected: (value) => _handleMenuSelection(context, value),
                itemBuilder: (context) {
                  final items = <PopupMenuEntry<String>>[];

                  // Only show "Other Races" if there are other races
                  if (hasOtherRaces && onShowOtherRaces != null) {
                    items.add(
                      const PopupMenuItem<String>(
                        value: 'load_other',
                        child: Row(
                          children: [
                            Icon(Icons.history, size: 18),
                            SizedBox(width: 8),
                            Text('Other Races'),
                          ],
                        ),
                      ),
                    );
                  }

                  // Show "See Runners" for bib recorder role
                  if (role == DeviceName.bibRecorder && onShowRunners != null) {
                    items.add(
                      const PopupMenuItem<String>(
                        value: 'see_runners',
                        child: Row(
                          children: [
                            Icon(Icons.people_outline, size: 18),
                            SizedBox(width: 8),
                            Text('See Runners'),
                          ],
                        ),
                      ),
                    );
                  }

                  // Always offer to get a race from the coach
                  if (onLoadRace != null) {
                    items.add(
                      const PopupMenuItem<String>(
                        value: 'load_new',
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 18),
                            SizedBox(width: 8),
                            // Wraps rather than overflowing the menu at
                            // larger text sizes.
                            Flexible(child: Text('Get Race from Coach')),
                          ],
                        ),
                      ),
                    );
                  }

                  // A copy of what this phone recorded, to save or send, in
                  // case sharing with the coach fails.
                  if (onDownloadRace != null) {
                    items.add(
                      const PopupMenuItem<String>(
                        value: 'download_race',
                        child: Row(
                          children: [
                            Icon(Icons.download_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Download a Copy'),
                          ],
                        ),
                      ),
                    );
                  }

                  if (onClearRecords != null &&
                      (canClearRecords?.call() ?? true)) {
                    items.add(
                      PopupMenuItem<String>(
                        value: 'clear_records',
                        child: Row(
                          children: [
                            const Icon(Icons.clear_all, size: 18),
                            const SizedBox(width: AppSpacing.sm),
                            Text(clearRecordsLabel),
                          ],
                        ),
                      ),
                    );
                  }

                  // Always show "Delete Race"
                  if (onDeleteRace != null) {
                    items.add(
                      const PopupMenuItem<String>(
                        value: 'delete_race',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete Race',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    );
                  }

                  return items;
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleMenuSelection(BuildContext context, String value) {
    switch (value) {
      case 'load_other':
        onShowOtherRaces?.call();
        break;
      case 'see_runners':
        onShowRunners?.call();
        break;
      case 'load_new':
        onLoadRace?.call();
        break;
      case 'download_race':
        onDownloadRace?.call();
        break;
      case 'clear_records':
        onClearRecords?.call();
        break;
      case 'delete_race':
        _showDeleteConfirmation(context);
        break;
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Delete Race?',
      content: 'This deletes "${currentRace!.formattedTitle}" and everything '
          'recorded for it from this phone. It cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      destructive: true,
    );
    if (confirmed) onDeleteRace?.call();
  }

  Future<List<RaceRecord>> _getOtherRaces() async {
    final result =
        await AssistantStorageService.instance.getRaces(role.toString());
    return switch (result) {
      Success(:final value) => value,
      Failure() => [],
    };
  }
}

/// Says the open race is only for practice, and how to get the real one.
class _PracticeRaceBanner extends StatelessWidget {
  const _PracticeRaceBanner({required this.onGetRace});

  final VoidCallback onGetRace;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: AppOpacity.light),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: AppOpacity.strong),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'This is a practice race. Before the race starts, get the real '
            'one from your coach.',
            style: AppTypography.bodyRegular.copyWith(
              color: AppColors.darkColor,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            text: 'Get Race from Coach',
            icon: Icons.download,
            size: ButtonSize.fullWidth,
            onPressed: onGetRace,
          ),
        ],
      ),
    );
  }
}

/// A simple notifier that can be used to trigger rebuilds when race data changes
class _RaceNotifier extends ChangeNotifier {
  RaceRecord _race;

  _RaceNotifier(this._race);

  RaceRecord get race => _race;

  void updateRace(RaceRecord newRace) {
    _race = newRace;
    notifyListeners();
  }
}
