import 'package:flutter/material.dart';
import '../../race_results/screen/results_screen.dart';
import '../widgets/race_details_tab.dart';
import '../controller/race_screen_controller.dart';
import '../../../core/components/sliding_page_view.dart';
import '../../runners_management_screen/screen/runners_management_screen.dart';
import '../widgets/race_header.dart';

class TabBarViewWidget extends StatefulWidget {
  final RaceController controller;
  const TabBarViewWidget({super.key, required this.controller});

  @override
  State<TabBarViewWidget> createState() => _TabBarViewWidgetState();
}

class _TabBarViewWidgetState extends State<TabBarViewWidget> {
  @override
  void initState() {
    super.initState();
    // Listen to controller changes to rebuild the widget
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TabBarView(
        controller: widget.controller.tabController,
        children: [
          // First tab: Race Details with sliding to Runners
          SlidingPageView(
            showSecondPage: widget.controller.showingRunnersManagement,
            secondPageTitle: 'Runners',
            onBackToFirst: () {
              widget.controller.navigateToRaceDetails(context).catchError((error) {
                debugPrint('Error navigating to race details: $error');
              });
            },
            firstPage: Column(
              children: [
                RaceHeader(
                  controller: widget.controller,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: RaceDetailsTab(
                      controller: widget.controller,
                    ),
                  ),
                ),
              ],
            ),
            secondPage: Builder(
              builder: (context) {
                if (widget.controller.showingRunnersManagement) {
                  return TeamsAndRunnersManagementWidget(
                    masterRace: widget.controller.masterRace,
                    showHeader: false,
                    isViewMode: true, // Always view mode when race is finished
                  );
                } else {
                  return Container(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Runners Management',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Navigate from the main screen to view runners',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          // Second tab: Results
          ResultsScreen(
            masterRace: widget.controller.masterRace,
          ),
        ],
      ),
    );
  }
}
