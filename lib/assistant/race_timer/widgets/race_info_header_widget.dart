import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../controller/timing_controller.dart';
import '../../../core/components/race_components.dart';

class RaceInfoHeaderWidget extends StatelessWidget {
  final TimingController controller;
  const RaceInfoHeaderWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    String status;
    Color statusColor;

    if (controller.startTime == null) {
      status = 'Ready';
      statusColor = Colors.black54;
    } else if (controller.raceStopped) {
      status = 'Finished';
      statusColor = Colors.green[700]!;
    } else {
      status = 'In progress';
      statusColor = AppColors.primaryColor;
    }

    // Get the last non-null place among uiRecords, or null if none
    late final int? lastPlace;
    try {
      lastPlace = controller.uiRecords
          .lastWhere((r) => r.place != null,
              orElse: () => throw Exception('No place found'))
          .place;
    } catch (e) {
      lastPlace = null;
    }

    return RaceStatusHeaderWidget(
      status: status,
      statusColor: statusColor,
      runnerCount: lastPlace,
      recordLabel: 'Runners',
    );
  }
}
