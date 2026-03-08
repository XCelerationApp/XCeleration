import 'package:flutter/material.dart';
import '../theme/app_animations.dart';
import '../theme/app_border_radius.dart';
import '../theme/app_colors.dart';
import '../theme/app_opacity.dart';
import '../theme/app_spacing.dart';
import '../theme/typography.dart';
import '../utils/color_utils.dart';
import '../utils/date_format_utils.dart';

/// Race-specific UI components
/// This file contains widgets specifically related to race management and display

/// Private sub-widget for the icon → gap → content row pattern used within
/// [RaceInfoHeaderWidget] (location row, date item, distance item).
class _RaceHeaderRow extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final Widget content;

  const _RaceHeaderRow({
    required this.icon,
    required this.iconSize,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: iconSize, color: AppColors.mediumColor),
        const SizedBox(width: AppSpacing.xs),
        content,
      ],
    );
  }
}

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
      margin: EdgeInsets.all(isCompact ? AppSpacing.sm : AppSpacing.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? AppSpacing.md : AppSpacing.lg),
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
                _RaceHeaderRow(
                  icon: Icons.location_on,
                  iconSize: isCompact ? AppSpacing.lg : 18,
                  content: Expanded(
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
                ),
              ],
              if (raceDate != null || (distance != null && distance! > 0)) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    if (raceDate != null)
                      _RaceHeaderRow(
                        icon: Icons.calendar_today,
                        iconSize: isCompact ? AppSpacing.md : AppSpacing.lg,
                        content: Text(
                          DateFormatUtils.formatRelativeDate(raceDate!),
                          style: AppTypography.caption
                              .copyWith(color: AppColors.mediumColor),
                        ),
                      ),
                    if (distance != null && distance! > 0) ...[
                      if (raceDate != null) const SizedBox(width: AppSpacing.lg),
                      _RaceHeaderRow(
                        icon: Icons.straighten,
                        iconSize: isCompact ? AppSpacing.md : AppSpacing.lg,
                        content: Text(
                          '${distance!.toStringAsFixed(distance! % 1 == 0 ? 0 : 1)} ${distanceUnit ?? 'mi'}',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.mediumColor),
                        ),
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


}

/// Private button widget with AnimatedScale press feedback.
class _ControlButton extends StatefulWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
    this.isCompact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isDestructive;
  final bool isCompact;

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _pressed = false;

  ButtonStyle get _buttonStyle {
    if (widget.isPrimary) {
      return ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      );
    }
    if (widget.isDestructive) {
      return ElevatedButton.styleFrom(
        backgroundColor: AppColors.redColor,
        foregroundColor: Colors.white,
      );
    }
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.lightColor,
      foregroundColor: AppColors.darkColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.onPressed != null
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: widget.onPressed != null
          ? () => setState(() => _pressed = false)
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: AppAnimations.fast,
        curve: AppAnimations.spring,
        child: ElevatedButton.icon(
          onPressed: widget.onPressed,
          icon: Icon(widget.icon, size: widget.isCompact ? 18.0 : 20.0),
          label: Text(widget.label),
          style: _buttonStyle,
        ),
      ),
    );
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
      margin: EdgeInsets.all(isCompact ? AppSpacing.sm : AppSpacing.lg),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? AppSpacing.md : AppSpacing.lg),
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
              SizedBox(height: isCompact ? AppSpacing.md : AppSpacing.lg),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!isRaceStarted) ...[
                  _ControlButton(
                    icon: Icons.play_arrow,
                    label: 'Start',
                    onPressed: onStart,
                    isPrimary: true,
                    isCompact: isCompact,
                  ),
                ] else if (isRacePaused) ...[
                  _ControlButton(
                    icon: Icons.play_arrow,
                    label: 'Cont.',
                    onPressed: onResume,
                    isPrimary: true,
                    isCompact: isCompact,
                  ),
                  _ControlButton(
                    icon: Icons.stop,
                    label: 'Stop',
                    onPressed: onStop,
                    isDestructive: true,
                    isCompact: isCompact,
                  ),
                ] else if (!isRaceFinished) ...[
                  _ControlButton(
                    icon: Icons.pause,
                    label: 'Pause',
                    onPressed: onPause,
                    isCompact: isCompact,
                  ),
                  _ControlButton(
                    icon: Icons.stop,
                    label: 'Stop',
                    onPressed: onStop,
                    isDestructive: true,
                    isCompact: isCompact,
                  ),
                ] else ...[
                  _ControlButton(
                    icon: Icons.refresh,
                    label: 'Reset',
                    onPressed: onReset,
                    isPrimary: true,
                    isCompact: isCompact,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md, horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(
            color: ColorUtils.withOpacity(Colors.grey, AppOpacity.medium)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AnimatedContainer(
            duration: AppAnimations.standard,
            curve: AppAnimations.spring,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: AppOpacity.light),
              borderRadius: BorderRadius.circular(AppBorderRadius.sm),
              border: Border.all(
                  color: statusColor.withValues(alpha: AppOpacity.strong)),
            ),
            child: Text(
              status,
              style: AppTypography.bodySemibold.copyWith(color: statusColor),
            ),
          ),
          if (runnerCount != null && onRunnersTap != null && showDropdown)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onRunnersTap,
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Runners: $runnerCount',
                      style: AppTypography.bodySemibold.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 20,
                      color: Colors.black54,
                    ),
                  ],
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
            const SizedBox(width: AppSpacing.lg),
            Text(
              '${recordLabel ?? 'Records'}: $recordCount',
              style: AppTypography.bodySemibold.copyWith(
                color: Colors.black87,
              ),
            ),
          ],
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
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      elevation: isEnabled ? 2 : 0,
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            border: Border.all(
              color: isEnabled ? color : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: AppSpacing.xxxl,
                height: AppSpacing.xxxl,
                decoration: BoxDecoration(
                  color: ColorUtils.withOpacity(
                      isEnabled ? color : Colors.grey, AppOpacity.light),
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? color : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
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
                    const SizedBox(height: AppSpacing.xs),
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
