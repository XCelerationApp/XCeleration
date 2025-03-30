import 'package:flutter/material.dart';
import 'package:xcelerate/utils/enums.dart';
import '../controller/race_screen_controller.dart';
import '../widgets/tab_bar.dart';
import '../widgets/tab_bar_view.dart';
import '../widgets/race_header.dart';
import '../widgets/race_details_tab.dart';

class RaceScreen extends StatefulWidget {
  final int raceId;
  final RaceScreenPage page;
  const RaceScreen({
    super.key,
    required this.raceId,
    this.page = RaceScreenPage.main,
  });

  @override
  RaceScreenState createState() => RaceScreenState();
}

class RaceScreenState extends State<RaceScreen> with TickerProviderStateMixin {
  // Controller
  late RaceScreenController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = RaceScreenController(raceId: widget.raceId);
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
  }

  @override
  void dispose() {
    _controller.tabController.dispose();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _controller.race == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Race Header
        RaceHeader(controller: _controller),
        if (_controller.race!.flowState != 'finished') ...[
          RaceDetailsTab(controller: _controller)
        ] else ...[
          // Tab Bar
          TabBarWidget(controller: _controller),
          // Tab Bar View
          TabBarViewWidget(controller: _controller),
        ],
      ],
    );
  }
}
