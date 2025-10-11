import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../shared/models/race_record.dart';

class OtherRacesSheet extends StatelessWidget {
  final List<RaceRecord> races;
  final RaceRecord? currentRace;
  final Function(RaceRecord) onRaceSelected;

  const OtherRacesSheet({
    super.key,
    required this.races,
    this.currentRace,
    required this.onRaceSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out the current race
    final otherRaces = races
        .where((race) => currentRace == null || race.raceId != currentRace!.raceId)
        .toList();

    if (otherRaces.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Other Races',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.darkColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Races list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: otherRaces.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final race = otherRaces[index];
              return _buildRaceCard(context, race);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 48,
            color: AppColors.mediumColor.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'No Other Races',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.darkColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRaceCard(BuildContext context, RaceRecord race) {
    final isCompleted = race.stopped && race.duration != null;
    final statusColor =
        isCompleted ? AppColors.primaryColor : AppColors.mediumColor;
    final isStarted = race.startedAt != null;
    final statusText = isCompleted ? 'Completed' : isStarted ? 'In Progress' : 'Not Started';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.lightColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pop(context);
            onRaceSelected(race);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    race.formattedTitle,
                    style: AppTypography.bodySemibold.copyWith(
                      color: AppColors.darkColor,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: AppTypography.caption.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
