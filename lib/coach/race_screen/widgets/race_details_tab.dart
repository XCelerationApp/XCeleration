import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/database_helper.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import 'package:xceleration/core/components/textfield_utils.dart';
import 'modern_detail_row.dart';
import '../controller/race_screen_controller.dart';
import 'inline_editable_field.dart';
import 'package:provider/provider.dart';
import 'dart:io';

class RaceDetailsTab extends StatefulWidget {
  final RaceController controller;
  const RaceDetailsTab({super.key, required this.controller});

  @override
  State<RaceDetailsTab> createState() => _RaceDetailsTabState();
}

class _RaceDetailsTabState extends State<RaceDetailsTab> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _teamsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _locationController.dispose();
    _distanceController.dispose();
    _unitController.dispose();
    _teamsController.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    final race = widget.controller.race!;
    _dateController.text = race.raceDate != null
        ? DateFormat('yyyy-MM-dd').format(race.raceDate!)
        : '';
    _locationController.text = race.location;
    _distanceController.text =
        race.distance > 0 ? race.distance.toString() : '';
    _unitController.text =
        race.distanceUnit.isNotEmpty ? race.distanceUnit : 'mi';
    _teamsController.text = race.teams.join(', ');
  }

  Widget _buildLocationEditWidget(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) {
                widget.controller.handleFieldFocusLoss(context, 'location');
              }
            },
            child: buildTextField(
              context: context,
              controller: widget.controller.locationController,
              hint: (Platform.isIOS || Platform.isAndroid)
                  ? 'Other location'
                  : 'Enter race location',
              error: widget.controller.locationError,
              setSheetState: (fn) => fn(),
              onChanged: (_) => widget.controller.trackFieldChange('location'),
              keyboardType: TextInputType.text,
            ),
          ),
        ),
        if (widget.controller.isLocationButtonVisible &&
            (Platform.isIOS || Platform.isAndroid)) ...[
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: IconButton(
              icon:
                  const Icon(Icons.my_location, color: AppColors.primaryColor),
              onPressed: () => widget.controller.getCurrentLocation(context),
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
                widget.controller.handleFieldFocusLoss(context, 'distance');
              }
            },
            child: buildTextField(
              context: context,
              controller: widget.controller.distanceController,
              hint: '0.0',
              error: widget.controller.distanceError,
              setSheetState: (fn) => fn(),
              onChanged: (_) => widget.controller.trackFieldChange('distance'),
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
                widget.controller.handleFieldFocusLoss(context, 'unit');
              }
            },
            child: buildDropdown(
              controller: widget.controller.unitController,
              hint: 'mi',
              error: null,
              setSheetState: (fn) => fn(),
              items: ['mi', 'km'],
              onChanged: (value) {
                widget.controller.unitController.text = value;
                widget.controller.trackFieldChange('unit');
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.controller,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final race = widget.controller.race!;
          int runnerCount = 0;

          return FutureBuilder(
            future: DatabaseHelper.instance.getRaceRunners(race.raceId),
            builder: (context, snapshot) {
              runnerCount = snapshot.hasData
                  ? (snapshot.data as List).length
                  : runnerCount;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        controller: widget.controller,
                        fieldName: 'location',
                        label: 'Location',
                        icon: Icons.location_on,
                        textController: widget.controller.locationController,
                        hint: (Platform.isIOS || Platform.isAndroid)
                            ? 'Other location'
                            : 'Enter race location',
                        error: widget.controller.locationError,
                        customEditWidget: _buildLocationEditWidget(context),
                      ),
                      InlineEditableField(
                        controller: widget.controller,
                        fieldName: 'date',
                        label: 'Race Date',
                        icon: Icons.calendar_today,
                        textController: widget.controller.dateController,
                        hint: 'YYYY-MM-DD',
                        error: widget.controller.dateError,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today,
                              color: AppColors.primaryColor),
                          onPressed: () =>
                              widget.controller.selectDate(context),
                        ),
                        getDisplayValue: () {
                          if (race.raceDate != null) {
                            return DateFormat('yyyy-MM-dd')
                                .format(race.raceDate!);
                          }
                          return 'Not set';
                        },
                      ),
                      InlineEditableField(
                        controller: widget.controller,
                        fieldName: 'distance',
                        label: 'Distance',
                        icon: Icons.straighten,
                        textController: widget.controller.distanceController,
                        hint: '0.0',
                        error: widget.controller.distanceError,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        customEditWidget: _buildDistanceEditWidget(context),
                        getDisplayValue: () {
                          return '${race.distance} ${race.distanceUnit}';
                        },
                      ),
                      // Teams field - read-only for now
                      ModernDetailRow(
                        label: 'Teams',
                        value: race.teams.join(', '),
                        icon: Icons.groups,
                      ),
                      const SizedBox(height: 16),
                      runnerCount == 0
                          ? Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              width: double.infinity,
                              child: TextButton(
                                onPressed: () => widget.controller
                                    .loadRunnersManagementScreenWithConfirmation(
                                        context,
                                        isViewMode: !widget.controller.canEdit),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                        color: AppColors.primaryColor),
                                  ),
                                ),
                                child: Text(
                                  'Load Runners',
                                  style: TextStyle(
                                    color: AppColors.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                          : InkWell(
                              onTap: () => widget.controller
                                  .loadRunnersManagementScreenWithConfirmation(
                                      context,
                                      isViewMode: !widget.controller.canEdit),
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
                                          color: AppColors.primaryColor,
                                          size: 22),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Runners',
                                            style: AppTypography.bodyRegular
                                                .copyWith(
                                              color: ColorUtils.withOpacity(
                                                  AppColors.darkColor, 0.6),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$runnerCount runner${runnerCount == 1 ? '' : 's'}',
                                            style: AppTypography.bodySemibold
                                                .copyWith(
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
                            )
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
