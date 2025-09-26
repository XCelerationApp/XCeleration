import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/enums.dart' hide EventTypes;
import 'package:xceleration/shared/models/database/master_race.dart';
import '../controller/race_screen_controller.dart';
import '../widgets/tab_bar.dart';
import '../widgets/tab_bar_view.dart';
import '../widgets/race_header.dart';
import '../widgets/race_details_tab.dart';
import '../../../core/services/event_bus.dart';
import '../../../shared/models/database/race.dart';
import 'dart:async';
import '../../races_screen/controller/races_controller.dart';
import '../../runners_management_screen/screen/runners_management_screen.dart';
import '../../../core/components/sliding_page_view.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/logger.dart';
import '../widgets/unsaved_changes_bar.dart';

class RaceScreen extends StatefulWidget {
  final RacesController parentController;
  final MasterRace masterRace;
  final RaceScreenPage page;
  const RaceScreen({
    super.key,
    required this.parentController,
    required this.masterRace,
    this.page = RaceScreenPage.main,
  });

  @override
  RaceScreenState createState() => RaceScreenState();
}

class RaceScreenState extends State<RaceScreen> with TickerProviderStateMixin {
  StreamSubscription? _flowStateSubscription;
  RaceController? _controller; // Store a reference to the controller

  @override
  void initState() {
    super.initState();
    // No manual controller instantiation; will use Provider
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _initializeRaceScreen());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safely store a reference to the controller
    _controller = Provider.of<RaceController>(context, listen: false);
  }

  @override
  void dispose() {
    // Use the stored controller reference instead of accessing Provider in dispose
    if (_controller?.tabController != null) {
      _controller!.tabController.dispose();
    }
    _flowStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeRaceScreen() async {
    try {
      final controller = Provider.of<RaceController>(context, listen: false);
      controller.tabController = TabController(length: 2, vsync: this);
      // Navigate to results page if specified
      if (widget.page == RaceScreenPage.results) {
        controller.tabController.animateTo(1);
      }
      // Add listener to update UI when tab changes
      controller.tabController.addListener(() {
        setState(() {}); // Refresh UI when tab changes
      });
      // Controller starts loading automatically when created
      // Subscribe to flow state changes to refresh UI when needed
      _flowStateSubscription =
          EventBus.instance.on(EventTypes.raceFlowStateChanged, (event) {
        // Only handle events for this race
        if (event.data != null &&
            event.data['raceId'] == widget.masterRace.raceId) {
          _refreshRaceData();
        }
      });
    } catch (e) {
      Logger.e('Error initializing race screen: $e');
      // Error handling is now managed by the controller
    }
  }

  // Refresh race data when flow state changes
  Future<void> _refreshRaceData() async {
    final controller = Provider.of<RaceController>(context, listen: false);
    // Controller handles its own refresh state
    await controller.refreshRaceData(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RaceController>(
      builder: (context, controller, _) {
        // Handle loading state
        if (controller.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading race data...'),
              ],
            ),
          );
        }

        // Handle error state
        if (controller.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text('Error loading race data'),
                SizedBox(height: 8),
                Text(
                  controller.error,
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => controller.loadAllData(context),
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Data available in controller - widgets access directly
        final flowState = controller.flowState;

        return Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (flowState != Race.FLOW_FINISHED) ...[
                  Expanded(
                    child: SlidingPageView(
                      showSecondPage: controller.showingRunnersManagement,
                      secondPageTitle: 'Runners',
                      onBackToFirst: () {
                        // Handle async navigation in a fire-and-forget manner
                        controller.navigateToRaceDetails().catchError((error) {
                          // Log error but don't block UI
                          debugPrint(
                              'Error navigating to race details: $error');
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
                          // Only build TeamsAndRunnersManagementWidget when it's actually shown
                          // This prevents it from creating listeners and causing infinite refresh loops
                          if (controller.showingRunnersManagement) {
                            return TeamsAndRunnersManagementWidget(
                              masterRace: widget.masterRace,
                              showHeader: false,
                              isViewMode: !controller.canEdit,
                            );
                          } else {
                            // Return a simple placeholder when not shown to avoid unnecessary widget creation
                            // The real widget will be built when controller.showingRunnersManagement becomes true
                            return Container(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.group,
                                        size: 48, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text(
                                      'Runners Management',
                                      style: TextStyle(
                                          fontSize: 18, color: Colors.grey),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Navigate from the main screen to manage runners',
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
                  )
                ] else ...[
                  // Tab Bar for finished races
                  TabBarWidget(controller: controller),
                  // Tab Bar View
                  TabBarViewWidget(controller: controller),
                ],
              ],
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: UnsavedChangesBar(controller: controller),
            ),
          ],
        );
      },
    );
  }
}
