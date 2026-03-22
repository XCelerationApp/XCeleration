import 'package:flutter/material.dart';
import '../../../coach/races_screen/controller/races_controller.dart';
import '../../../shared/models/database/race.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/components/empty_section.dart';
import 'race_card.dart';
import '../../flows/widgets/flow_section_header.dart';

class RacesList extends StatefulWidget {
  final RacesController controller;
  final bool canEdit;
  const RacesList({super.key, required this.controller, this.canEdit = true});

  @override
  State<RacesList> createState() => _RacesListState();
}

class _RacesListState extends State<RacesList> {
  bool _inProgressExpanded = true;
  bool _upcomingExpanded = true;
  bool _finishedExpanded = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final List<Race> raceData = widget.controller.races;
    final finishedRaces =
        raceData.where((race) => race.flowState == Race.FLOW_FINISHED).toList();
    final raceInProgress = raceData
        .where((race) =>
            race.flowState == Race.FLOW_POST_RACE ||
            race.flowState == Race.FLOW_PRE_RACE ||
            race.flowState == Race.FLOW_PRE_RACE_COMPLETED)
        .toList();
    final upcomingRaces = raceData
        .where((race) =>
            race.flowState == Race.FLOW_SETUP ||
            race.flowState == Race.FLOW_SETUP_COMPLETED)
        .toList();

    final totalItems =
        raceInProgress.length + upcomingRaces.length + finishedRaces.length;
    final useStagger = totalItems <= 20;

    // Build flat list: section header + card items
    final items = <_ListItem>[];

    void addSection({
      required String title,
      required List<Race> races,
      required bool isExpanded,
      required VoidCallback onToggle,
      required Widget emptyState,
      required int startIndex,
    }) {
      items.add(_HeaderItem(
        title: title,
        count: races.length,
        isExpanded: isExpanded,
        onToggle: onToggle,
      ));
      if (isExpanded) {
        if (races.isEmpty) {
          items.add(_WidgetItem(emptyState));
        } else {
          for (int i = 0; i < races.length; i++) {
            final globalIndex = startIndex + i;
            final race = races[i];
            items.add(_CardItem(
              race: race,
              controller: widget.controller,
              canEdit: widget.canEdit,
              useStagger: useStagger,
              index: globalIndex,
            ));
          }
        }
      }
    }

    addSection(
      title: 'In Progress',
      races: raceInProgress,
      isExpanded: _inProgressExpanded,
      onToggle: () => setState(() => _inProgressExpanded = !_inProgressExpanded),
      emptyState: const EmptySection(
        icon: Icons.timer_outlined,
        title: 'No races in progress',
        subtitle: 'Active races will appear here',
      ),
      startIndex: 0,
    );
    addSection(
      title: 'Upcoming',
      races: upcomingRaces,
      isExpanded: _upcomingExpanded,
      onToggle: () => setState(() => _upcomingExpanded = !_upcomingExpanded),
      emptyState: const EmptySection(
        icon: Icons.calendar_today_outlined,
        title: 'No upcoming races',
        subtitle: 'Races you\'re setting up will appear here',
      ),
      startIndex: raceInProgress.length,
    );
    addSection(
      title: 'Finished',
      races: finishedRaces,
      isExpanded: _finishedExpanded,
      onToggle: () => setState(() => _finishedExpanded = !_finishedExpanded),
      emptyState: const EmptySection(
        icon: Icons.history,
        title: 'No finished races yet',
        subtitle: 'Completed races will appear here',
      ),
      startIndex: raceInProgress.length + upcomingRaces.length,
    );

    return SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => items[index].build(context),
    );
  }
}

sealed class _ListItem {
  Widget build(BuildContext context);
}

class _HeaderItem extends _ListItem {
  final String title;
  final int count;
  final bool isExpanded;
  final VoidCallback onToggle;

  _HeaderItem({
    required this.title,
    required this.count,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return FlowSectionHeader(
      title: title,
      count: count,
      isExpanded: isExpanded,
      onToggle: onToggle,
    );
  }
}

class _WidgetItem extends _ListItem {
  final Widget child;
  _WidgetItem(this.child);

  @override
  Widget build(BuildContext context) => child;
}

class _CardItem extends _ListItem {
  final Race race;
  final RacesController controller;
  final bool canEdit;
  final bool useStagger;
  final int index;

  _CardItem({
    required this.race,
    required this.controller,
    required this.canEdit,
    required this.useStagger,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final card = RaceCard(
      race: race,
      flowState: race.flowState ?? '',
      controller: controller,
      canEdit: canEdit,
    );
    return useStagger ? _AnimatedListItem(index: index, child: card) : card;
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
