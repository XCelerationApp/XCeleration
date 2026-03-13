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
import 'dart:io';
import '../../../shared/models/database/race.dart';

class RaceDetailsTab extends StatelessWidget {
  final RaceController controller;

  const RaceDetailsTab({
    super.key,
    required this.controller,
  });

  Widget _buildLocationEditWidget(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) {
                controller.handleFieldFocusLoss(context, RaceField.location);
              }
            },
            child: buildTextField(
              context: context,
              controller: controller.form.locationController,
              hint: (Platform.isIOS || Platform.isAndroid)
                  ? 'Other location'
                  : 'Enter race location',
              error: controller.form.errorFor(RaceField.location),
              onChanged: (_) => controller.trackFieldChange(RaceField.location),
              keyboardType: TextInputType.text,
            ),
          ),
        ),
        if (controller.isLocationButtonVisible &&
            (Platform.isIOS || Platform.isAndroid)) ...[
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 1,
            child: IconButton(
              icon:
                  const Icon(Icons.my_location, color: AppColors.primaryColor),
              onPressed: () => controller.getCurrentLocation(context),
            ),
          ),
        ]
      ],
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
    final race = controller.race;
    final raceRunners = controller.raceRunners;
    final teams = controller.teams;
    final canEdit = controller.canEdit;
    final runnerCount = raceRunners.length;
    final teamCount = teams.length;

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
            hint: (Platform.isIOS || Platform.isAndroid)
                ? 'Other location'
                : 'Enter race location',
            error: controller.form.errorFor(RaceField.location),
            customEditWidget: _buildLocationEditWidget(context),
          ),
          InlineEditableField(
            controller: controller,
            field: RaceField.date,
            label: 'Race Date',
            icon: Icons.calendar_today,
            textController: controller.form.dateController,
            hint: 'YYYY-MM-DD',
            error: controller.form.errorFor(RaceField.date),
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_today,
                  color: AppColors.primaryColor),
              onPressed: () => controller.selectDate(context),
            ),
            getDisplayValue: () {
              if (race.raceDate != null) {
                return DateFormat('yyyy-MM-dd').format(race.raceDate!);
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

          const SizedBox(height: AppSpacing.lg),
          if (runnerCount > 0)
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
                )
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
        padding: const EdgeInsets.all(AppSpacing.xs),
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
                    '${widget.teamCount} team${widget.teamCount == 1 ? '' : 's'}, ${widget.runnerCount} runner${widget.runnerCount == 1 ? '' : 's'}',
                    style: AppTypography.bodySemibold.copyWith(
                      color: AppColors.darkColor,
                    ),
                    maxLines: 1,
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
