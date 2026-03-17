import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/controller/bib_recorder_v2_controller.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Race-selection lobby shown before a race is active.
class RaceLobbyWidget extends StatelessWidget {
  const RaceLobbyWidget({super.key, required this.controller});

  final BibRecorderV2Controller controller;

  @override
  Widget build(BuildContext context) {
    final ready = controller.races
        .where((r) => !r.stopped)
        .toList();
    final done = controller.races
        .where((r) => r.stopped)
        .toList();

    return ColoredBox(
      color: AppColors.backgroundColor,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: controller.races.isEmpty
                  ? _EmptyState()
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
                                onTap: () => controller.selectRace(r),
                              )),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        if (done.isNotEmpty) ...[
                          _SectionLabel(label: 'Done'),
                          const SizedBox(height: AppSpacing.sm),
                          ...done.map((r) => _RaceCard(
                                race: r,
                                onTap: () => controller.selectRace(r),
                              )),
                        ],
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
  const _RaceCard({required this.race, required this.onTap});

  final RaceRecord race;
  final VoidCallback onTap;

  @override
  State<_RaceCard> createState() => _RaceCardState();
}

class _RaceCardState extends State<_RaceCard> {
  bool _pressed = false;

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

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏁', style: TextStyle(fontSize: 40)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No races yet',
            style: AppTypography.smallBodyRegular.copyWith(
              color: AppColors.lightColor,
            ),
          ),
        ],
      ),
    );
  }
}
