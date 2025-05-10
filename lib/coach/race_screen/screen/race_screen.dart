import 'package:flutter/material.dart';
import 'package:xceleration/utils/enums.dart';
import '../controller/race_screen_controller.dart';
import '../widgets/tab_bar.dart';
import '../widgets/tab_bar_view.dart';
import '../widgets/race_header.dart';
import '../widgets/race_details_tab.dart';
import '../../../core/services/event_bus.dart';
import '../../../shared/models/race.dart';
import 'dart:async';
import '../../races_screen/controller/races_controller.dart';

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
  // Controller
  late RaceController _controller;
  bool _isLoading = true;
  StreamSubscription? _flowStateSubscription;

  @override
  void initState() {
    super.initState();
    _controller = RaceController(parentController: widget.parentController, raceId: widget.raceId);
    _controller.setContext(context);
    _controller.tabController = TabController(length: 2, vsync: this);

    // Navigate to results page if specified
    if (widget.page == RaceScreenPage.results) {
      _controller.tabController.animateTo(1);
    }

    // Add listener to update UI when tab changes
    _controller.tabController.addListener(() {
      setState(() {}); // Refresh UI when tab changes
    });

    _loadRaceData();
    
    // Subscribe to flow state changes to refresh UI when needed
    _flowStateSubscription = EventBus.instance.on(EventTypes.raceFlowStateChanged, (event) {
      // Only handle events for this race
      if (event.data != null && event.data['raceId'] == widget.raceId) {
        _refreshRaceData();
      }
    });
  }

  @override
  void dispose() {
    _controller.tabController.dispose();
    _flowStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadRaceData() async {
    await _controller.init(context);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Refresh race data when flow state changes
  Future<void> _refreshRaceData() async {
    setState(() {
      _isLoading = true;
    });
    
    final updatedRace = await _controller.loadRace();
    
    if (mounted && updatedRace != null) {
      setState(() {
        _controller.race = updatedRace;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _controller.race == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Race Header
            RaceHeader(controller: _controller),
            if (_controller.race!.flowState != Race.FLOW_FINISHED) ...[
              Expanded(
                child: SingleChildScrollView(
                  child: RaceDetailsTab(controller: _controller),
                ),
              )
            ] else ...[
              // Tab Bar for finished races
              TabBarWidget(controller: _controller),
              // Tab Bar View
              TabBarViewWidget(controller: _controller),
            ],
          ],
        );
      },
    );
  }
}
