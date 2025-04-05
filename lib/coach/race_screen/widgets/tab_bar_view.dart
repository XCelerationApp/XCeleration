import 'package:flutter/material.dart';
import '../../race_results/screen/results_screen.dart';
import '../widgets/race_details_tab.dart';
import '../controller/race_screen_controller.dart';

class TabBarViewWidget extends StatefulWidget {
  final RaceScreenController controller;
  const TabBarViewWidget({super.key, required this.controller});

  @override
  State<TabBarViewWidget> createState() => _TabBarViewWidgetState();
}

class _TabBarViewWidgetState extends State<TabBarViewWidget> {
  // Default minimum height to avoid initial layout issues
  double _currentHeight = 250;
  
  // Global keys to measure content height
  final GlobalKey _detailsKey = GlobalKey();
  final GlobalKey _resultsKey = GlobalKey();
  
  // Keep track of measured heights
  double _detailsHeight = 250;
  double _resultsHeight = 250;

  @override
  void initState() {
    super.initState();
    // Add listener to tab changes to adjust height
    widget.controller.tabController.addListener(_handleTabChange);
    
    // Initial measurement after first render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureCurrentTab();
    });
  }

  @override
  void dispose() {
    widget.controller.tabController.removeListener(_handleTabChange);
    super.dispose();
  }

  void _handleTabChange() {
    // Apply the appropriate height when tab changes
    if (mounted) {
      setState(() {
        _currentHeight = widget.controller.tabController.index == 0 
          ? _detailsHeight 
          : _resultsHeight;
      });
      
      // Measure the newly visible tab after it renders
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _measureCurrentTab();
      });
    }
  }
  
  void _measureCurrentTab() {
    if (!mounted) return;
    
    // Only measure the active tab
    final int currentTab = widget.controller.tabController.index;
    
    try {
      if (currentTab == 0 && _detailsKey.currentContext != null) {
        final RenderBox box = _detailsKey.currentContext!.findRenderObject() as RenderBox;
        if (box.hasSize) {
          _detailsHeight = box.size.height;
          if (mounted) {
            setState(() {
              _currentHeight = _detailsHeight;
            });
          }
        }
      } else if (currentTab == 1 && _resultsKey.currentContext != null) {
        final RenderBox box = _resultsKey.currentContext!.findRenderObject() as RenderBox;
        if (box.hasSize) {
          _resultsHeight = box.size.height;
          if (mounted) {
            setState(() {
              _currentHeight = _resultsHeight;
            });
          }
        }
      }
    } catch (e) {
      // In case of an error with the rendering, use default height
      print('Error measuring tab height: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TabBarView(
        controller: widget.controller.tabController,
        children: [
          Container(
            key: _detailsKey,
            child: RaceDetailsTab(controller: widget.controller),
          ),

          Container(
            key: _resultsKey,
            child: ResultsScreen(
              raceId: widget.controller.raceId,
            ),
          ),
        ],
      ),
    );
  }
}
