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
  RaceScreenController? _controller; // Store a reference to the controller

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
    _controller = Provider.of<RaceScreenController>(context, listen: false);
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
      final controller = Provider.of<RaceScreenController>(context, listen: false);
      controller.tabController = TabController(length: 2, vsync: this);
      // Navigate to results page if specified
      if (widget.page == RaceScreenPage.results) {
        controller.tabController.animateTo(1);
      }
      // Add listener to update UI when tab changes.
      // Guard against every animation tick — only rebuild when the tab
      // index has fully settled to a new value.
      int lastTabIndex = controller.tabController.index;
      controller.tabController.addListener(() {
        if (!controller.tabController.indexIsChanging &&
            controller.tabController.index != lastTabIndex) {
          lastTabIndex = controller.tabController.index;
          setState(() {});
        }
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
    final controller = Provider.of<RaceScreenController>(context, listen: false);
    // Controller handles its own refresh state
    await controller.refreshRaceData(context);
  }

  @override
  Widget build(BuildContext context) {
    // Outer Selector: only rebuilds when loading or error state changes.
    // This is the rarest state transition (initial load, retry).
    return Selector<RaceScreenController, ({bool isLoading, bool hasError, String error})>(
      selector: (_, c) => (
        isLoading: c.isLoading,
        hasError: c.hasError,
        error: c.hasError ? c.error : '',
      ),
      builder: (context, state, _) {
        if (state.isLoading) {
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

        if (state.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Error loading race data'),
                const SizedBox(height: 8),
                Text(
                  state.error,
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context
                      .read<RaceScreenController>()
                      .loadAllData(context),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return _RaceScreenContent(
          masterRace: widget.masterRace,
        );
      },
    );
  }
}

/// Stateless body rendered once loading is complete.
///
/// Uses targeted [Selector]s so that different sub-trees only rebuild when
/// the state they actually depend on changes:
/// - Layout structure rebuilds on [flowState] or [showingRunnersManagement]
/// - [UnsavedChangesBar] rebuilds on its own slice of form + runner state
class _RaceScreenContent extends StatelessWidget {
  final MasterRace masterRace;
  const _RaceScreenContent({required this.masterRace});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<RaceScreenController>();

    return Stack(
      children: [
        // Inner Selector: controls layout structure.
        // Rebuilds only when flowState or navigation state changes —
        // not on keystrokes or form-only updates.
        Selector<RaceScreenController,
            ({String flowState, bool showingRunners})>(
          selector: (_, c) => (
            flowState: c.flowState,
            showingRunners: c.showingRunnersManagement,
          ),
          builder: (context, state, _) {
            return Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.flowState != Race.FLOW_FINISHED) ...[
                  RaceHeader(controller: controller),
                  Expanded(
                    child: SlidingPageView(
                      showSecondPage: state.showingRunners,
                      onBackToFirst: () {
                        controller
                            .navigateToRaceDetails(context)
                            .catchError((error) {
                          debugPrint(
                              'Error navigating to race details: $error');
                        });
                      },
                      firstPage: SingleChildScrollView(
                        child: RaceDetailsTab(controller: controller),
                      ),
                      secondPage: Builder(
                        builder: (context) {
                          if (state.showingRunners) {
                            return TeamsAndRunnersManagementWidget(
                              masterRace: masterRace,
                              showHeader: true,
                              onBack: () => controller
                                  .navigateToRaceDetails(context)
                                  .catchError((e) => debugPrint('$e')),
                              isViewMode: !controller.canEdit,
                            );
                          }
                          // Lightweight placeholder — avoids constructing
                          // the full runners widget before it is visible.
                          return Container(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.group,
                                      size: 48, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Runners Management',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Navigate from the main screen to manage runners',
                                    textAlign: TextAlign.center,
                                    style:
                                        TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ] else ...[
                  RaceHeader(controller: controller),
                  TabBarWidget(controller: controller),
                  TabBarViewWidget(controller: controller),
                ],
              ],
            );
          },
        ),
        // UnsavedChangesBar Selector: rebuilds only when form dirty state,
        // runner presence, or flow state changes — not on layout navigation.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Selector<RaceScreenController,
              ({bool hasUnsaved, bool runnersEmpty, String flowState})>(
            selector: (_, c) => (
              hasUnsaved: c.form.hasUnsavedChanges,
              runnersEmpty: c.raceRunners.isEmpty,
              flowState: c.flowState,
            ),
            builder: (_, __, ___) =>
                UnsavedChangesBar(controller: controller),
          ),
        ),
      ],
    );
  }
}
