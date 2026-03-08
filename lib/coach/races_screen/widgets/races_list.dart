import 'package:flutter/material.dart';
import '../../../coach/races_screen/controller/races_controller.dart';
import '../../../shared/models/database/race.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/components/empty_section_state.dart';
import 'race_card.dart';
import '../../flows/widgets/flow_section_header.dart';

class RacesList extends StatelessWidget {
  final RacesController controller;
  final bool canEdit;
  const RacesList({super.key, required this.controller, this.canEdit = true});

  @override
  Widget build(BuildContext context) {
    return _buildList();
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

    List<Widget> buildRaceCards(List<Race> races) {
      return [
        for (final race in races)
          Builder(builder: (context) {
            final index = itemIndex++;
            final card = RaceCard(
              race: race,
              flowState: race.flowState!,
              controller: controller,
              canEdit: canEdit,
            );
            return useStagger
                ? _AnimatedListItem(index: index, child: card)
                : card;
          }),
      ];
    }

    return Column(
      key: const ValueKey('list'),
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CollapsibleSection(
          title: 'In Progress',
          count: raceInProgress.length,
          emptyState: const EmptySectionState(
            icon: Icons.timer_outlined,
            title: 'No races in progress',
            subtitle: 'Active races will appear here',
          ),
          children: buildRaceCards(raceInProgress),
        ),
        _CollapsibleSection(
          title: 'Upcoming',
          count: upcomingRaces.length,
          emptyState: const EmptySectionState(
            icon: Icons.calendar_today_outlined,
            title: 'No upcoming races',
            subtitle: 'Races you\'re setting up will appear here',
          ),
          children: buildRaceCards(upcomingRaces),
        ),
        _CollapsibleSection(
          title: 'Finished',
          count: finishedRaces.length,
          emptyState: const EmptySectionState(
            icon: Icons.history,
            title: 'No finished races yet',
            subtitle: 'Completed races will appear here',
          ),
          children: buildRaceCards(finishedRaces),
        ),
      ],
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  final String title;
  final int count;
  final Widget emptyState;
  final List<Widget> children;

  const _CollapsibleSection({
    required this.title,
    required this.count,
    required this.emptyState,
    required this.children,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlowSectionHeader(
          title: widget.title,
          count: widget.count,
          isExpanded: _isExpanded,
          onToggle: () => setState(() => _isExpanded = !_isExpanded),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _isExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.count == 0
                      ? [widget.emptyState]
                      : widget.children,
                )
              : const SizedBox.shrink(),
        ),
      ],
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
