import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../controller/race_screen_controller.dart';

class TabBarWidget extends StatelessWidget {
  final RaceScreenController controller;
  const TabBarWidget({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TabBar(
            controller: controller.tabController,
            labelColor: AppColors.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primaryColor,
            indicatorWeight: 3.0, 
            indicatorPadding: const EdgeInsets.only(bottom: 5.0,), 
            labelPadding: const EdgeInsets.only(bottom: 8.0), 
            tabs: const [
              Tab(text: 'Race Details', icon: Icon(Icons.flag)),
              Tab(text: 'Results', icon: Icon(Icons.assessment)),
            ],
          ),
        ),
      ],
    );
  }
}