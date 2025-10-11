import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/enums.dart';
import '../controller/timing_controller.dart';
import '../../shared/services/assistant_storage_service.dart';

class RaceHeaderWidget extends StatelessWidget {
  final TimingController controller;

  const RaceHeaderWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            if (controller.currentRace == null) {
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
          ElevatedButton(
            onPressed: () => controller.showLoadRaceSheet(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor.withValues(alpha: 0.9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
              controller.currentRace!.formattedTitle,
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
                  if (hasOtherRaces) {
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

                  // Always show "Load New Race"
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

                  // Always show "Delete Race"
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
        controller.showOtherRaces(context);
        break;
      case 'load_new':
        controller.showLoadRaceSheet(context);
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
          'Are you sure you want to delete "${controller.currentRace!.formattedTitle}"? This action cannot be undone.',
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
        controller.deleteCurrentRace();
      }
    });
  }

  Future<List<dynamic>> _getOtherRaces() async {
    try {
      final races = await AssistantStorageService.instance
          .getRaces(DeviceName.raceTimer.toString());
      return races;
    } catch (e) {
      return [];
    }
  }
}
