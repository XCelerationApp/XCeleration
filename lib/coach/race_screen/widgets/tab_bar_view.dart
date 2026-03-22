import 'package:flutter/material.dart';
import '../../race_results/screen/results_screen.dart';
import '../widgets/race_details_tab.dart';
import '../controller/race_screen_controller.dart';
import '../../../core/components/sliding_page_view.dart';
import '../../runners_management_screen/screen/runners_management_screen.dart';
import '../widgets/race_header.dart';

/// Shared placeholder shown in the second page of the [SlidingPageView]
/// before the runners management panel is navigated to.
class RunnersManagementPlaceholder extends StatelessWidget {
  final String message;

  const RunnersManagementPlaceholder({
    super.key,
    this.message = 'Navigate from the main screen to manage runners',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Runners Management',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class TabBarViewWidget extends StatelessWidget {
  final RaceScreenController controller;
  const TabBarViewWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TabBarView(
        controller: controller.tabController,
        children: [
          // First tab: Race Details with sliding to Runners.
          // Wrapped in ListenableBuilder so only this tab rebuilds when the
          // controller notifies — ResultsScreen is intentionally excluded.
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => SlidingPageView(
              showSecondPage: controller.showingRunnersManagement,
              onBackToFirst: () {
                controller
                    .navigateToRaceDetails(context)
                    .catchError((error) {
                  debugPrint('Error navigating to race details: $error');
                });
              },
              firstPage: Column(
                children: [
                  RaceHeader(
                    controller: controller,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: RaceDetailsTab(
                        controller: controller,
                      ),
                    ),
                  ),
                ],
              ),
              secondPage: Builder(
                builder: (context) {
                  if (controller.showingRunnersManagement) {
                    return TeamsAndRunnersManagementWidget(
                      masterRace: controller.masterRace,
                      showHeader: true,
                      onBack: () => controller
                          .navigateToRaceDetails(context)
                          .catchError((e) => debugPrint('$e')),
                      isViewMode: true, // Always view mode when race is finished
                    );
                  } else {
                    return const RunnersManagementPlaceholder(
                      message: 'Navigate from the main screen to view runners',
                    );
                  }
                },
              ),
            ),
          ),
          // Second tab: Results — not inside ListenableBuilder, so controller
          // notifications do not trigger a rebuild here.
          ResultsScreen(
            masterRace: controller.masterRace,
          ),
        ],
      ),
    );
  }
}
