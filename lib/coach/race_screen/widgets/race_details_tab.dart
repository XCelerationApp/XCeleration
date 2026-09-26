import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import 'package:xceleration/core/components/textfield_utils.dart';
import '../controller/race_screen_controller.dart';
import '../controller/race_form_state.dart';
import 'inline_editable_field.dart';
import '../../../shared/models/database/race.dart';

class RaceDetailsTab extends StatelessWidget {
  final RaceScreenController controller;

  const RaceDetailsTab({
    super.key,
    required this.controller,
  });

  Widget _buildLocationEditWidget(BuildContext context) {
    // Typed, like "Crystal Springs". A locate button used to fill in the
    // phone's street address or coordinates, which coaches found confusing.
    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          controller.handleFieldFocusLoss(context, RaceField.location);
        }
      },
      child: buildTextField(
        context: context,
        controller: controller.form.locationController,
        hint: 'Where is the race? e.g. Crystal Springs',
        error: controller.form.errorFor(RaceField.location),
        onChanged: (_) => controller.trackFieldChange(RaceField.location),
        keyboardType: TextInputType.text,
      ),
    );
  }

  Widget _buildDateEditWidget(BuildContext context) {
    // A calendar, not typing a date in a set format.
    return buildTextField(
      context: context,
      controller: controller.form.dateController,
      hint: 'Tap to pick a date',
      error: controller.form.errorFor(RaceField.date),
      readOnly: true,
      onTap: () => controller.selectDate(context),
      suffixIcon: IconButton(
        tooltip: 'Pick a date',
        icon: const Icon(Icons.calendar_today, color: AppColors.primaryColor),
        onPressed: () => controller.selectDate(context),
      ),
      onChanged: (_) => controller.trackFieldChange(RaceField.date),
    );
  }

  Widget _buildDistanceEditWidget(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) {
                controller.handleFieldFocusLoss(context, RaceField.distance);
              }
            },
            child: buildTextField(
              context: context,
              controller: controller.form.distanceController,
              hint: '0.0',
              error: controller.form.errorFor(RaceField.distance),
              onChanged: (_) => controller.trackFieldChange(RaceField.distance),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 1,
          child: Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) {
                controller.handleFieldFocusLoss(context, RaceField.unit);
              }
            },
            child: AppDropdownField(
              controller: controller.form.unitController,
              hint: 'mi',
              items: ['mi', 'km'],
              onChanged: (value) {
                controller.form.unitController.text = value;
                controller.trackFieldChange(RaceField.unit);
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilt whenever the race or its form changes. The race screen above
    // only rebuilds for a few things, so tapping a field's pencil marked it
    // for editing without redrawing it, and the pencil seemed to do nothing.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildDetails(context),
    );
  }

  Widget _buildDetails(BuildContext context) {
    final race = controller.race;
    final raceRunners = controller.raceRunners;
    final teams = controller.teams;
    final canEdit = controller.canEdit;
    final runnerCount = raceRunners.length;
    // A runner's team counts even if it was never added to the race itself:
    // races that came from another phone before those links synced lack them.
    final teamCount = {
      for (final team in teams) team.teamId,
      for (final runner in raceRunners) runner.team.teamId,
    }.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          // Inline editable fields
          InlineEditableField(
            controller: controller,
            field: RaceField.location,
            label: 'Location',
            icon: Icons.location_on,
            textController: controller.form.locationController,
            hint: 'Where is the race?',
            error: controller.form.errorFor(RaceField.location),
            maxDisplayLines: 2,
            customEditWidget: _buildLocationEditWidget(context),
          ),
          InlineEditableField(
            controller: controller,
            field: RaceField.date,
            label: 'Race Date',
            icon: Icons.calendar_today,
            textController: controller.form.dateController,
            hint: 'Tap to pick a date',
            error: controller.form.errorFor(RaceField.date),
            customEditWidget: _buildDateEditWidget(context),
            getDisplayValue: () {
              if (race.raceDate != null) {
                return DateFormat('EEE, MMM d, yyyy').format(race.raceDate!);
              }
              return 'Not set';
            },
          ),
          InlineEditableField(
            controller: controller,
            field: RaceField.distance,
            label: 'Distance',
            icon: Icons.straighten,
            textController: controller.form.distanceController,
            hint: '0.0',
            error: controller.form.errorFor(RaceField.distance),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            customEditWidget: _buildDistanceEditWidget(context),
            getDisplayValue: () {
              return '${race.distance} ${race.distanceUnit}';
            },
          ),

          Builder(
            builder: (context) {
              final isViewMode = !canEdit ||
                  race.flowState == Race.FLOW_FINISHED ||
                  race.flowState == Race.FLOW_POST_RACE;
              return _TeamsRow(
                teamCount: teamCount,
                runnerCount: runnerCount,
                onTap: () =>
                    controller.loadRunnersManagementScreenWithConfirmation(
                        context,
                        isViewMode: isViewMode),
              );
            },
          ),
          // Room to scroll the last row above the Save Changes bar.
          const SizedBox(height: AppSpacing.xxxl * 2),
        ],
      ),
    );
  }
}

class _TeamsRow extends StatefulWidget {
  const _TeamsRow({
    required this.teamCount,
    required this.runnerCount,
    required this.onTap,
  });

  final int teamCount;
  final int runnerCount;
  final VoidCallback onTap;

  @override
  State<_TeamsRow> createState() => _TeamsRowState();
}

class _TeamsRowState extends State<_TeamsRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.spring,
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: AppOpacity.light),
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
              ),
              child: Icon(Icons.group_rounded,
                  color: AppColors.primaryColor, size: 22),
              // Same size as the other rows' icons, so they line up.
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teams and Runners',
                    style: AppTypography.bodyRegular.copyWith(
                      color: AppColors.mediumColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.runnerCount == 0
                        ? 'None yet. Tap to add'
                        : '${widget.teamCount} team${widget.teamCount == 1 ? '' : 's'}, ${widget.runnerCount} runner${widget.runnerCount == 1 ? '' : 's'}',
                    style: AppTypography.bodySemibold.copyWith(
                      color: widget.runnerCount == 0
                          ? AppColors.primaryColor
                          : AppColors.darkColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.primaryColor,
                  size: 28,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
