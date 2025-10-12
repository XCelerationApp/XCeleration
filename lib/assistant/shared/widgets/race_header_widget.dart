import 'package:flutter/material.dart';
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

  const RaceHeaderWidget({
    super.key,
    required this.currentRace,
    required this.role,
    this.onLoadRace,
    this.onShowOtherRaces,
    this.onDeleteRace,
    this.onShowRunners,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            if (currentRace != null) _RaceNotifier(currentRace!),
          ]),
          builder: (context, child) {
            if (currentRace == null) {
              return _buildNoRaceBanner(context);
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
              'No Race Loaded',
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
                'Load',
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          const SizedBox(width: 8),
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

                  // Always show "Load New Race"
                  if (onLoadRace != null) {
                    items.add(
                      const PopupMenuItem<String>(
                        value: 'load_new',
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 18),
                            SizedBox(width: 8),
                            Text('Load New Race'),
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
      case 'delete_race':
        _showDeleteConfirmation(context);
        break;
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Race'),
        content: Text(
          'Are you sure you want to delete "${currentRace!.formattedTitle}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        onDeleteRace?.call();
      }
    });
  }

  Future<List<dynamic>> _getOtherRaces() async {
    try {
      final races =
          await AssistantStorageService.instance.getRaces(role.toString());
      return races;
    } catch (e) {
      return [];
    }
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
