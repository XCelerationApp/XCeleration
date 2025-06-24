import 'package:flutter/material.dart';
// import '../constants/app_constants.dart' as constants; // Unused
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';

/// Common UI components used throughout the application
/// This consolidates duplicate widgets and provides consistent styling

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

/// Reusable loading indicator with consistent styling
class LoadingWidget extends StatelessWidget {
  final String? message;
  final bool isCompact;

  const LoadingWidget({
    super.key,
    this.message,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
          ),
          if (message != null) ...[
            SizedBox(height: isCompact ? 12 : 16),
            Text(
              message!,
              style: AppTypography.bodyRegular
                  .copyWith(color: AppColors.mediumColor),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Reusable error widget with consistent styling
class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool isCompact;

  const AppErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 16.0 : 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: isCompact ? 48 : 64,
              color: AppColors.redColor,
            ),
            SizedBox(height: isCompact ? 12 : 16),
            Text(
              'Oops! Something went wrong',
              style: isCompact
                  ? AppTypography.titleMedium
                  : AppTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isCompact ? 8 : 12),
            Text(
              message,
              style: AppTypography.bodyRegular
                  .copyWith(color: AppColors.mediumColor),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              SizedBox(height: isCompact ? 16 : 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reusable empty state widget
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onAction;
  final String? actionLabel;
  final bool isCompact;

  const EmptyStateWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onAction,
    this.actionLabel,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 16.0 : 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.inbox,
              size: isCompact ? 48 : 64,
              color: AppColors.mediumColor,
            ),
            SizedBox(height: isCompact ? 12 : 16),
            Text(
              title,
              style: isCompact
                  ? AppTypography.titleMedium
                  : AppTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: isCompact ? 8 : 12),
              Text(
                subtitle!,
                style: AppTypography.bodyRegular
                    .copyWith(color: AppColors.mediumColor),
                textAlign: TextAlign.center,
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              SizedBox(height: isCompact ? 16 : 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reusable search bar widget
class SearchBarWidget extends StatelessWidget {
  final String? hintText;
  final String? value;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool isCompact;

  const SearchBarWidget({
    super.key,
    this.hintText,
    this.value,
    this.onChanged,
    this.onClear,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(isCompact ? 8.0 : 16.0),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightColor),
      ),
      child: TextField(
        controller: value != null ? TextEditingController(text: value) : null,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText ?? 'Search...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: value != null && value!.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isCompact ? 12 : 16,
          ),
        ),
      ),
    );
  }
}

/// Reusable section header widget
class SectionHeaderWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool isCompact;

  const SectionHeaderWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12.0 : 16.0,
        vertical: isCompact ? 8.0 : 12.0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: isCompact
                      ? AppTypography.titleMedium
                      : AppTypography.titleLarge,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: AppTypography.bodyRegular
                        .copyWith(color: AppColors.mediumColor),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
