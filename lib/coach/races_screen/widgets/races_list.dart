import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import '../../../coach/races_screen/controller/races_controller.dart';
import '../../../shared/models/database/race.dart';
import '../../../../core/theme/typography.dart';
import 'race_card.dart';
import '../../flows/widgets/flow_section_header.dart';

class RacesList extends StatelessWidget {
  final RacesController controller;
  const RacesList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.races.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Center(
          child: Text('No races.', style: AppTypography.bodyRegular),
        ),
      );
    }

    final List<Race> raceData = controller.races;
    Logger.d(raceData.toString());
    final finishedRaces =
        raceData.where((race) => race.flowState == Race.FLOW_FINISHED).toList();
    final raceInProgress = raceData
        .where((race) =>
            race.flowState == Race.FLOW_POST_RACE ||
            race.flowState == Race.FLOW_PRE_RACE ||
            race.flowState == Race.FLOW_PRE_RACE_COMPLETED)
        // race.flowState == Race.FLOW_POST_RACE_COMPLETED)
        .toList();
    final upcomingRaces = raceData
        .where((race) =>
            race.flowState == Race.FLOW_SETUP ||
            race.flowState == Race.FLOW_SETUP_COMPLETED)
        .toList();
    return SingleChildScrollView(
      controller: ScrollController(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (raceInProgress.isNotEmpty) ...[
            FlowSectionHeader(title: 'In Progress'),
            ...raceInProgress.map((race) => RaceCard(
                race: race, flowState: race.flowState!, controller: controller)),
          ],
          if (upcomingRaces.isNotEmpty) ...[
            FlowSectionHeader(title: 'Upcoming'),
            ...upcomingRaces.map((race) => RaceCard(
                race: race, flowState: race.flowState!, controller: controller)),
          ],
          if (finishedRaces.isNotEmpty) ...[
            FlowSectionHeader(title: 'Finished'),
            ...finishedRaces.map((race) => RaceCard(
                race: race, flowState: race.flowState!, controller: controller)),
          ],
        ],
      ),
    );
  }
}
