import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/enums.dart' hide EventTypes;
import '../controller/race_screen_controller.dart';
import '../widgets/tab_bar.dart';
import '../widgets/tab_bar_view.dart';
import '../widgets/race_header.dart';
import '../widgets/race_details_tab.dart';
import '../../../core/services/event_bus.dart';
import '../../../shared/models/race.dart';
import 'dart:async';
import '../../races_screen/controller/races_controller.dart';
import '../../runners_management_screen/screen/runners_management_screen.dart';
import '../../../core/components/sliding_page_view.dart';
import 'package:provider/provider.dart';

class RaceScreen extends StatefulWidget {
  final RacesController parentController;
  final int raceId;
  final RaceScreenPage page;
  const RaceScreen({
    super.key,
    required this.parentController,
    required this.raceId,
    this.page = RaceScreenPage.main,
  });

  @override
  RaceScreenState createState() => RaceScreenState();
}

class RaceScreenState extends State<RaceScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  StreamSubscription? _flowStateSubscription;
  RaceController? _controller; // Store a reference to the controller

  @override
  void initState() {
    super.initState();
    // No manual controller instantiation; will use Provider
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRaceData());
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

  Future<void> _loadRaceData() async {
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
    await controller.init(context);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
    // Subscribe to flow state changes to refresh UI when needed
    _flowStateSubscription =
        EventBus.instance.on(EventTypes.raceFlowStateChanged, (event) {
      // Only handle events for this race
      if (event.data != null && event.data['raceId'] == widget.raceId) {
        _refreshRaceData();
      }
    });
  }

  // Refresh race data when flow state changes
  Future<void> _refreshRaceData() async {
    setState(() {
      _isLoading = true;
    });
    final controller = Provider.of<RaceController>(context, listen: false);
    final updatedRace = await controller.loadRace();
    if (mounted && updatedRace != null) {
      setState(() {
        controller.race = updatedRace;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<RaceController>(context);
    if (_isLoading || controller.race == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.race!.flowState != Race.FLOW_FINISHED) ...[
              Expanded(
                child: SlidingPageView(
                  showSecondPage: controller.showingRunnersManagement,
                  secondPageTitle: 'Runners',
                  onBackToFirst: controller.navigateToRaceDetails,
                  firstPage: Column(
                    children: [
                      RaceHeader(controller: controller),
                      Expanded(
                        child: SingleChildScrollView(
                          child: RaceDetailsTab(controller: controller),
                        ),
                      ),
                    ],
                  ),
                  secondPage: RunnersManagementScreen(
                    raceId: controller.raceId,
                    showHeader: false,
                    isViewMode: !controller.canEdit,
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
        );
      },
    );
  }
}
