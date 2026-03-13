import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:xceleration/core/utils/sheet_utils.dart' show sheet;
import 'package:xceleration/shared/models/database/master_race.dart';
import '../controller/races_controller.dart';
import '../../race_screen/controller/race_screen_controller.dart';
import '../../race_screen/screen/race_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_animations.dart';
import '../../../shared/models/database/race.dart';
import '../../../core/theme/typography.dart';
import '../../../core/components/status_badge.dart';

class RaceCard extends StatefulWidget {
  const RaceCard({
    super.key,
    required this.race,
    required this.flowState,
    required this.controller,
    this.canEdit = true,
  });

  final Race race;
  final String flowState;
  final RacesController controller;
  final bool canEdit;

  @override
  State<RaceCard> createState() => _RaceCardState();
}

class _RaceCardState extends State<RaceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: Key(widget.race.raceId?.toString() ?? 'unknown'),
      endActionPane: _buildActionPane(),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.mediumColor.withValues(alpha: AppOpacity.light),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border(
            left: BorderSide(color: AppColors.primaryColor, width: 5),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: () async {
              final masterRace =
                  MasterRace.getInstance(widget.race.raceId ?? 0);
              if (!context.mounted) return;
              await sheet(
                context: context,
                body: ChangeNotifierProvider(
                  create: (ctx) {
                    final raceController = RaceController(
                      masterRace: masterRace,
                      parentController: widget.controller,
                    );
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      raceController.loadAllData(ctx);
                    });
                    return raceController;
                  },
                  child: RaceScreen(
                    masterRace: masterRace,
                    parentController: widget.controller,
                  ),
                ),
                takeUpScreen: false,
                showHeader: true,
              );
              await widget.controller.loadRaces();
            },
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              curve: AppAnimations.spring,
              color: _pressed
                  ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
                  : Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.lg),
                child: _buildCardContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  ActionPane _buildActionPane() {
    return ActionPane(
      extentRatio: 0.5,
      motion: const DrawerMotion(),
      dragDismissible: false,
      children: [
        if (widget.canEdit)
          CustomSlidableAction(
            onPressed: (context) =>
                widget.controller.editRace(widget.race, context),
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            autoClose: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.edit_outlined, color: Colors.white, size: 24),
                const SizedBox(height: AppSpacing.xs),
                Text('Edit',
                    style:
                        AppTypography.bodySmall.copyWith(color: Colors.white)),
              ],
            ),
          ),
        if (widget.canEdit)
          CustomSlidableAction(
            onPressed: (context) =>
                widget.controller.deleteRace(widget.race, context),
            backgroundColor: AppColors.redColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            autoClose: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.delete_outline, size: 24, color: Colors.white),
                const SizedBox(height: AppSpacing.xs),
                Text('Delete',
                    style:
                        AppTypography.bodySmall.copyWith(color: Colors.white)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCardContent() {
    final race = widget.race;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(race.raceName ?? 'Unnamed Race',
                  style: AppTypography.headerSemibold),
            ),
            StatusBadge(flowState: widget.flowState),
          ],
        ),
        if (race.location != null && race.location!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _RaceCardLocation(location: race.location!),
        ],
        if (race.raceDate != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _RaceCardDate(date: race.raceDate!),
        ],
        if (race.distance != null && race.distance! > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          _RaceCardDistance(
              distance: race.distance!, unit: race.distanceUnit ?? ''),
        ],
      ],
    );
  }
}

class _RaceCardLocation extends StatelessWidget {
  const _RaceCardLocation({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.location_on, size: 20, color: AppColors.primaryColor),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            location,
            style:
                AppTypography.bodyRegular.copyWith(color: AppColors.mediumColor),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _RaceCardDate extends StatelessWidget {
  const _RaceCardDate({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.calendar_today,
            size: 20, color: AppColors.primaryColor),
        const SizedBox(width: AppSpacing.sm),
        Text(
          DateFormat('MMM d, y').format(date),
          style:
              AppTypography.bodyRegular.copyWith(color: AppColors.mediumColor),
        ),
      ],
    );
  }
}

class _RaceCardDistance extends StatelessWidget {
  const _RaceCardDistance({required this.distance, required this.unit});

  final double distance;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.straighten_rounded,
            size: 20, color: AppColors.primaryColor),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$distance $unit',
          style: AppTypography.headerSemibold
              .copyWith(color: AppColors.primaryColor),
        ),
      ],
    );
  }
}
