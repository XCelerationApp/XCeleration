import 'package:flutter/material.dart';
import '../../../coach/races_screen/controller/races_controller.dart';
import '../../../shared/models/database/race.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_animations.dart';
import 'race_card.dart';
import '../../flows/widgets/flow_section_header.dart';

class RacesList extends StatelessWidget {
  final RacesController controller;
  final bool canEdit;
  const RacesList({super.key, required this.controller, this.canEdit = true});

  @override
  Widget build(BuildContext context) {
    final isEmpty = controller.races.isEmpty;

    return AnimatedSwitcher(
      duration: AppAnimations.standard,
      child: isEmpty
          ? Padding(
              key: const ValueKey('empty'),
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: Center(
                child: Text('No races.', style: AppTypography.headerRegular),
              ),
            )
          : _buildList(),
    );
  }

  Widget _buildList() {
    final List<Race> raceData = controller.races;
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

    final totalItems =
        raceInProgress.length + upcomingRaces.length + finishedRaces.length;
    final useStagger = totalItems <= 20;

    int itemIndex = 0;
    final List<Widget> children = [];

    if (raceInProgress.isNotEmpty) {
      children.add(FlowSectionHeader(title: 'In Progress'));
      for (final race in raceInProgress) {
        final index = itemIndex++;
        final card = RaceCard(
          race: race,
          flowState: race.flowState!,
          controller: controller,
          canEdit: canEdit,
        );
        children.add(
          useStagger ? _AnimatedListItem(index: index, child: card) : card,
        );
      }
    }

    if (upcomingRaces.isNotEmpty) {
      children.add(FlowSectionHeader(title: 'Upcoming'));
      for (final race in upcomingRaces) {
        final index = itemIndex++;
        final card = RaceCard(
          race: race,
          flowState: race.flowState!,
          controller: controller,
          canEdit: canEdit,
        );
        children.add(
          useStagger ? _AnimatedListItem(index: index, child: card) : card,
        );
      }
    }

    if (finishedRaces.isNotEmpty) {
      children.add(FlowSectionHeader(title: 'Finished'));
      for (final race in finishedRaces) {
        final index = itemIndex++;
        final card = RaceCard(
          race: race,
          flowState: race.flowState!,
          controller: controller,
          canEdit: canEdit,
        );
        children.add(
          useStagger ? _AnimatedListItem(index: index, child: card) : card,
        );
      }
    }

    return Column(
      key: const ValueKey('list'),
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _AnimatedListItem extends StatefulWidget {
  const _AnimatedListItem({required this.child, required this.index});

  final Widget child;
  final int index;

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: AppAnimations.reveal,
      curve: AppAnimations.enter,
      child: widget.child,
    );
  }
}
