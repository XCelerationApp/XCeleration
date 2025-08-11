import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import 'package:xceleration/core/components/textfield_utils.dart';
import '../controller/race_screen_controller.dart';
import 'inline_editable_field.dart';
import 'dart:io';

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
                controller.handleFieldFocusLoss(context, 'location');
              }
            },
            child: buildTextField(
              context: context,
              controller: controller.locationController,
              hint: (Platform.isIOS || Platform.isAndroid)
                  ? 'Other location'
                  : 'Enter race location',
              error: controller.locationError,
              setSheetState: (fn) => fn(),
              onChanged: (_) => controller.trackFieldChange('location'),
              keyboardType: TextInputType.text,
            ),
          ),
        ),
        if (controller.isLocationButtonVisible &&
            (Platform.isIOS || Platform.isAndroid)) ...[
          const SizedBox(width: 12),
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
                controller.handleFieldFocusLoss(context, 'distance');
              }
            },
            child: buildTextField(
              context: context,
              controller: controller.distanceController,
              hint: '0.0',
              error: controller.distanceError,
              setSheetState: (fn) => fn(),
              onChanged: (_) => controller.trackFieldChange('distance'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) {
                controller.handleFieldFocusLoss(context, 'unit');
              }
            },
            child: buildDropdown(
              controller: controller.unitController,
              hint: 'mi',
              error: null,
              setSheetState: (fn) => fn(),
              items: ['mi', 'km'],
              onChanged: (value) {
                controller.unitController.text = value;
                controller.trackFieldChange('unit');
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

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Race Details',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          // Inline editable fields
          InlineEditableField(
            controller: controller,
            fieldName: 'location',
            label: 'Location',
            icon: Icons.location_on,
            textController: controller.locationController,
            hint: (Platform.isIOS || Platform.isAndroid)
                ? 'Other location'
                : 'Enter race location',
            error: controller.locationError,
            customEditWidget: _buildLocationEditWidget(context),
          ),
          InlineEditableField(
            controller: controller,
            fieldName: 'date',
            label: 'Race Date',
            icon: Icons.calendar_today,
            textController: controller.dateController,
            hint: 'YYYY-MM-DD',
            error: controller.dateError,
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
            fieldName: 'distance',
            label: 'Distance',
            icon: Icons.straighten,
            textController: controller.distanceController,
            hint: '0.0',
            error: controller.distanceError,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            customEditWidget: _buildDistanceEditWidget(context),
            getDisplayValue: () {
              return '${race.distance} ${race.distanceUnit}';
            },
          ),

          const SizedBox(height: 16),
          runnerCount == 0
              ? Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: double.infinity,
                  child: Builder(
                    builder: (context) {
                      final isViewMode = !canEdit;
                      return TextButton(
                        onPressed: () => controller
                            .loadRunnersManagementScreenWithConfirmation(
                                context,
                                isViewMode: isViewMode),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: AppColors.primaryColor),
                          ),
                        ),
                        child: Text(
                          'Load Teams and Runners',
                          style: TextStyle(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                )
              : Builder(
                  builder: (context) {
                    final isViewMode = !canEdit;
                    return InkWell(
                      onTap: () => controller
                          .loadRunnersManagementScreenWithConfirmation(context,
                              isViewMode: isViewMode),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: ColorUtils.withOpacity(
                                    AppColors.primaryColor, 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.group_rounded,
                                  color: AppColors.primaryColor, size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Teams and Runners',
                                    style: AppTypography.bodyRegular.copyWith(
                                      color: ColorUtils.withOpacity(
                                          AppColors.darkColor, 0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$teamCount team${teamCount == 1 ? '' : 's'}, $runnerCount runner${runnerCount == 1 ? '' : 's'}',
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
                                const SizedBox(width: 8),
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
                  },
                )
        ],
      ),
    ]);
  }
}
