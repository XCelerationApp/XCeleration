import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/widgets/confirm_bottom_sheet.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Race-selection lobby shown before a race is active.
///
/// Shared across Bib Recorder V2, Verifier, and Fixer. The parent screen
/// owns controller state and passes data + callbacks down.
class RaceLobbyWidget extends StatelessWidget {
  const RaceLobbyWidget({
    super.key,
    required this.races,
    required this.onSelectRace,
    required this.onDeleteRace,
    required this.onGetFromCoach,
  });

  final List<RaceRecord> races;
  final void Function(RaceRecord race) onSelectRace;
  final void Function(int raceId) onDeleteRace;
  final VoidCallback onGetFromCoach;

  @override
  Widget build(BuildContext context) {
    final ready = races.where((r) => !r.stopped).toList();
    final done = races.where((r) => r.stopped).toList();

    return ColoredBox(
      color: AppColors.backgroundColor,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: races.isEmpty
                  ? _EmptyState(onGetFromCoach: onGetFromCoach)
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      children: [
                        if (ready.isNotEmpty) ...[
                          _SectionLabel(label: 'Ready'),
                          const SizedBox(height: AppSpacing.sm),
                          ...ready.map((r) => _RaceCard(
                                race: r,
                                onTap: () => onSelectRace(r),
                                onDelete: () => onDeleteRace(r.raceId),
                              )),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        if (done.isNotEmpty) ...[
                          _SectionLabel(label: 'Done'),
                          const SizedBox(height: AppSpacing.sm),
                          ...done.map((r) => _RaceCard(
                                race: r,
                                onTap: () => onSelectRace(r),
                                onDelete: () => onDeleteRace(r.raceId),
                              )),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        _GetFromCoachButton(
                          onTap: onGetFromCoach,
                          isSecondary: true,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTypography.bodySmall.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.mediumColor,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _RaceCard extends StatefulWidget {
  const _RaceCard({
    required this.race,
    required this.onTap,
    required this.onDelete,
  });

  final RaceRecord race;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_RaceCard> createState() => _RaceCardState();
}

class _RaceCardState extends State<_RaceCard> {
  bool _pressed = false;

  void _showDeleteConfirm(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConfirmBottomSheet(
        title: 'Delete Race?',
        message:
            'Permanently deletes all records for ${widget.race.formattedName}.',
        confirmLabel: 'Delete',
        onConfirm: widget.onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          curve: AppAnimations.spring,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: _pressed
                ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
                : Colors.white,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.race.formattedName,
                      style: AppTypography.smallBodySemibold.copyWith(
                        color: AppColors.darkColor,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.race.formattedDate,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.mediumColor,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(stopped: widget.race.stopped),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: () => _showDeleteConfirm(context),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.mediumColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.stopped});

  final bool stopped;

  @override
  Widget build(BuildContext context) {
    if (stopped) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.lightColor.withValues(alpha: AppOpacity.medium),
          borderRadius: BorderRadius.circular(AppBorderRadius.full),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Text(
          'Done',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.mediumColor,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.liveBackground,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
        border: Border.all(color: AppColors.liveBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.redColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Ready',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.redColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _GetFromCoachButton extends StatefulWidget {
  const _GetFromCoachButton({required this.onTap, required this.isSecondary});

  final VoidCallback onTap;
  final bool isSecondary;

  @override
  State<_GetFromCoachButton> createState() => _GetFromCoachButtonState();
}

class _GetFromCoachButtonState extends State<_GetFromCoachButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isPrimary = !widget.isSecondary;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.spring,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isPrimary
              ? (_pressed
                  ? AppColors.darkPrimaryColor
                  : AppColors.primaryColor)
              : (_pressed
                  ? AppColors.primaryColor.withValues(alpha: AppOpacity.light)
                  : AppColors.primaryColor.withValues(alpha: AppOpacity.faint)),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(
            color: isPrimary
                ? Colors.transparent
                : AppColors.primaryColor.withValues(alpha: AppOpacity.strong),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_rounded,
              size: 18,
              color: isPrimary ? Colors.white : AppColors.primaryColor,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              isPrimary ? 'Get Race from Coach' : 'Sync a new race from Coach',
              style: AppTypography.smallBodySemibold.copyWith(
                color: isPrimary ? Colors.white : AppColors.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onGetFromCoach});

  final VoidCallback onGetFromCoach;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          const Text('🏁', style: TextStyle(fontSize: 40)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No races yet',
            style: AppTypography.smallBodyRegular.copyWith(
              color: AppColors.lightColor,
            ),
          ),
          const Spacer(),
          _GetFromCoachButton(onTap: onGetFromCoach, isSecondary: false),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
