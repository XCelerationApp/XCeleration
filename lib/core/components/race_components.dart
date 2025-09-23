import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/typography.dart';
import '../utils/color_utils.dart';

/// Race-specific UI components
/// This file contains widgets specifically related to race management and display

/// Reusable race information header widget
class RaceInfoHeaderWidget extends StatelessWidget {
  final String raceName;
  final String? location;
  final DateTime? raceDate;
  final double? distance;
  final String? distanceUnit;
  final VoidCallback? onTap;
  final bool isCompact;

  const RaceInfoHeaderWidget({
    super.key,
    required this.raceName,
    this.location,
    this.raceDate,
    this.distance,
    this.distanceUnit,
    this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(isCompact ? 8.0 : 16.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 12.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                raceName,
                style: isCompact
                    ? AppTypography.bodyRegular
                        .copyWith(fontWeight: FontWeight.bold)
                    : AppTypography.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (location != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: isCompact ? 16 : 18,
                      color: AppColors.mediumColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location!,
                        style: isCompact
                            ? AppTypography.smallBodyRegular
                                .copyWith(color: AppColors.mediumColor)
                            : AppTypography.bodyRegular
                                .copyWith(color: AppColors.mediumColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (raceDate != null || (distance != null && distance! > 0)) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (raceDate != null) ...[
                      Icon(
                        Icons.calendar_today,
                        size: isCompact ? 14 : 16,
                        color: AppColors.mediumColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(raceDate!),
                        style: AppTypography.caption
                            .copyWith(color: AppColors.mediumColor),
                      ),
                    ],
                    if (distance != null && distance! > 0) ...[
                      if (raceDate != null) const SizedBox(width: 16),
                      Icon(
                        Icons.straighten,
                        size: isCompact ? 14 : 16,
                        color: AppColors.mediumColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${distance!.toStringAsFixed(distance! % 1 == 0 ? 0 : 1)} ${distanceUnit ?? 'mi'}',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.mediumColor),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference == -1) return 'Yesterday';
    if (difference > 0 && difference <= 7) return 'In $difference days';
    if (difference < 0 && difference >= -7) return '${-difference} days ago';

    return '${date.month}/${date.day}/${date.year}';
  }
}

/// Reusable race controls widget with consistent styling
class RaceControlsWidget extends StatelessWidget {
  final bool isRaceStarted;
  final bool isRacePaused;
  final bool isRaceFinished;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onStop;
  final VoidCallback? onReset;
  final String? currentTime;
  final bool isCompact;

  const RaceControlsWidget({
    super.key,
    required this.isRaceStarted,
    required this.isRacePaused,
    required this.isRaceFinished,
    this.onStart,
    this.onPause,
    this.onResume,
    this.onStop,
    this.onReset,
    this.currentTime,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(isCompact ? 8.0 : 16.0),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12.0 : 16.0),
        child: Column(
          children: [
            if (currentTime != null) ...[
              Text(
                currentTime!,
                style: isCompact
                    ? AppTypography.displaySmall
                        .copyWith(fontWeight: FontWeight.bold)
                    : AppTypography.displayMedium
                        .copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isCompact ? 12 : 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!isRaceStarted) ...[
                  _buildControlButton(
                    context,
                    icon: Icons.play_arrow,
                    label: 'Start',
                    onPressed: onStart,
                    isPrimary: true,
                  ),
                ] else if (isRacePaused) ...[
                  _buildControlButton(
                    context,
                    icon: Icons.play_arrow,
                    label: 'Resume',
                    onPressed: onResume,
                    isPrimary: true,
                  ),
                  _buildControlButton(
                    context,
                    icon: Icons.stop,
                    label: 'Stop',
                    onPressed: onStop,
                    isDestructive: true,
                  ),
                ] else if (!isRaceFinished) ...[
                  _buildControlButton(
                    context,
                    icon: Icons.pause,
                    label: 'Pause',
                    onPressed: onPause,
                  ),
                  _buildControlButton(
                    context,
                    icon: Icons.stop,
                    label: 'Stop',
                    onPressed: onStop,
                    isDestructive: true,
                  ),
                ] else ...[
                  _buildControlButton(
                    context,
                    icon: Icons.refresh,
                    label: 'Reset',
                    onPressed: onReset,
                    isPrimary: true,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
    bool isPrimary = false,
    bool isDestructive = false,
  }) {
    final buttonStyle = isPrimary
        ? ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
          )
        : isDestructive
            ? ElevatedButton.styleFrom(
                backgroundColor: AppColors.redColor,
                foregroundColor: Colors.white,
              )
            : ElevatedButton.styleFrom(
                backgroundColor: AppColors.lightColor,
                foregroundColor: AppColors.darkColor,
              );

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: isCompact ? 18 : 20),
      label: Text(label),
      style: buttonStyle,
    );
  }
}

/// Shared race status header widget that consolidates RaceInfoHeaderWidget implementations
class RaceStatusHeaderWidget extends StatelessWidget {
  final String status;
  final Color statusColor;
  final int? runnerCount;
  final int? recordCount;
  final String? recordLabel;
  final VoidCallback? onRunnersTap;
  final bool showDropdown;

  const RaceStatusHeaderWidget({
    super.key,
    required this.status,
    required this.statusColor,
    this.runnerCount,
    this.recordCount,
    this.recordLabel,
    this.onRunnersTap,
    this.showDropdown = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorUtils.withOpacity(Colors.grey, 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status,
            style: AppTypography.bodySemibold.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (runnerCount != null && onRunnersTap != null && showDropdown)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onRunnersTap,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Runners: $runnerCount',
                            style: AppTypography.bodySemibold.copyWith(
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down,
                            size: 20,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (runnerCount != null)
                Text(
                  'Runners: $runnerCount',
                  style: AppTypography.bodySemibold.copyWith(
                    color: Colors.black87,
                  ),
                ),
              if (recordCount != null) ...[
                const SizedBox(width: 16),
                Text(
                  '${recordLabel ?? 'Records'}: $recordCount',
                  style: AppTypography.bodySemibold.copyWith(
                    color: Colors.black87,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Shared conflict button for handling conflicts in race results
class ConflictButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool isEnabled;

  const ConflictButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: isEnabled ? 2 : 0,
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEnabled ? color : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ColorUtils.withOpacity(
                      isEnabled ? color : Colors.grey, 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? color : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodySemibold.copyWith(
                        color: isEnabled ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTypography.smallBodyRegular.copyWith(
                        color: isEnabled ? Colors.black54 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (isEnabled)
                Icon(
                  Icons.arrow_forward_ios,
                  color: color,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
