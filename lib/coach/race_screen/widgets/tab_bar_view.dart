import 'package:flutter/material.dart';
import '../../race_results/screen/results_screen.dart';
import '../widgets/race_details_tab.dart';
import '../controller/race_screen_controller.dart';

class TabBarViewWidget extends StatefulWidget {
  final RaceController controller;
  const TabBarViewWidget({super.key, required this.controller});

  @override
  State<TabBarViewWidget> createState() => _TabBarViewWidgetState();
}

class _TabBarViewWidgetState extends State<TabBarViewWidget> {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TabBarView(
        controller: widget.controller.tabController,
        children: [
          RaceDetailsTab(controller: widget.controller),
          ResultsScreen(
            masterRace: widget.controller.masterRace,
          ),
        ],
      ),
    );
  }
}
