import 'package:flutter/material.dart';
import '../../results_screen/screen/results_screen.dart';
import '../widgets/race_details_tab.dart';
import '../controller/race_screen_controller.dart';



class TabBarViewWidget extends StatelessWidget {
  final RaceScreenController controller;
  const TabBarViewWidget({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TabBarView(
        controller: controller.tabController,
        children: [
          // Race details content
          RaceDetailsTab(controller: controller),
          
          // Results content
          ResultsScreen(
            raceId: controller.raceId,
          ),
        ],
      ),
    );
  }
}