import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../controller/race_screen_controller.dart';

/// Race screen that displays all information and actions for a specific race
class RaceScreen extends StatefulWidget {
  final int raceId;
  
  const RaceScreen({Key? key, required this.raceId}) : super(key: key);

  @override
  RaceScreenState createState() => RaceScreenState();
}

class RaceScreenState extends State<RaceScreen> with TickerProviderStateMixin {
  // Controllers
  late AnimationController _slideController;
  late RaceScreenController _controller;
  
  // UI state
  int _selectedTabIndex = 0;
  
  @override
  void initState() {
    super.initState();
    // Initialize controllers
    _controller = RaceScreenController(raceId: widget.raceId);
    
    _controller.addListener(_updateUI);
    
    // Animation controller for slide animation
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _loadRace();
  }
  
  @override
  void dispose() {
    _slideController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Update UI when controller data changes
  void _updateUI() {
    if (mounted) {
      setState(() {});
    }
  }
  
  /// Load race data
  Future<void> _loadRace() async {
    await _controller.loadRace();
    
    // Continue race flow if needed
    _continueRaceFlow();
  }
  
  /// Continue race flow based on current state
  Future<void> _continueRaceFlow() async {
    if (_controller.race == null) return;
    
    // Use the FlowController through the RaceScreenController to start the current flow
    await _controller.startCurrentFlow(context);
  }

  @override
  Widget build(BuildContext context) {
    final race = _controller.race;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(race?.raceName ?? 'Race'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRace,
          ),
        ],
      ),
      body: race == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildRaceHeader(),
                Expanded(
                  child: DefaultTabController(
                    length: 3,
                    initialIndex: _selectedTabIndex,
                    child: Column(
                      children: [
                        TabBar(
                          onTap: (index) {
                            setState(() {
                              _selectedTabIndex = index;
                            });
                          },
                          tabs: const [
                            Tab(text: 'DETAILS'),
                            Tab(text: 'RUNNERS'),
                            Tab(text: 'RESULTS'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildDetailsView(),
                              _buildRunnersView(),
                              _buildResultsView(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }
  
  Widget _buildRaceHeader() {
    final race = _controller.race;
    if (race == null) return const SizedBox.shrink();
    
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                race.raceName,
                style: AppTypography.titleSemibold,
              ),
              const SizedBox(height: 4),
              Text(
                'Status: ${_getStatusText(race.flowState)}',
                style: AppTypography.bodyRegular,
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _continueRaceFlow,
            icon: Icon(
              race.flowState == 'finished' ? Icons.emoji_events : Icons.play_arrow,
            ),
            label: Text(
              race.flowState == 'finished' ? 'View Results' : 'Continue',
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailsView() {
    final race = _controller.race;
    if (race == null) return const Center(child: CircularProgressIndicator());
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Race Details', style: AppTypography.titleSemibold),
          const SizedBox(height: 16),
          _buildDetailCard(
            'General Information',
            [
              {'title': 'Race Date', 'value': race.raceDate.toString().split(' ')[0]},
              {'title': 'Race Type', 'value': 'Cross Country'},
              {'title': 'Distance', 'value': '${race.distance}${race.distanceUnit}'},
              {'title': 'Location', 'value': race.location},
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailCard(
            'Teams',
            race.teams.map((team) => {
              'title': team,
              'value': '',
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Map<String, String>> items) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.titleSemibold),
            const SizedBox(height: 16),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item['title']!, style: AppTypography.bodySemibold),
                  Text(item['value']!, style: AppTypography.bodyRegular),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRunnersView() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _controller.getRaceRunners(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading runners: ${snapshot.error}'),
          );
        }
        
        final runners = snapshot.data ?? [];
        
        if (runners.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No Runners Added Yet',
                  style: AppTypography.titleSemibold.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Go to the setup flow to add runners',
                  style: AppTypography.bodyRegular.copyWith(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Runners (${runners.length})', style: AppTypography.titleSemibold),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Manage'),
                    onPressed: () => _continueRaceFlow(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: runners.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final runner = runners[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryColor.withOpacity(0.2),
                      child: Text(
                        runner['bib_number']?.toString() ?? '?',
                        style: TextStyle(color: AppColors.primaryColor),
                      ),
                    ),
                    title: Text(runner['name'] ?? 'Unknown'),
                    subtitle: Text(runner['school'] ?? 'No school'),
                    trailing: Text('Grade: ${runner['grade'] ?? 'N/A'}'),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResultsView() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _controller.getRaceResults(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading results: ${snapshot.error}'),
          );
        }
        
        final results = snapshot.data ?? [];
        
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No Results Yet',
                  style: AppTypography.titleSemibold.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete the race to see results here',
                  style: AppTypography.bodyRegular.copyWith(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }
        
        // Sort results by place
        results.sort((a, b) => (a['place'] as int? ?? 999).compareTo(b['place'] as int? ?? 999));
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Results', style: AppTypography.titleSemibold),
                  if (_controller.hasTimingConflicts || _controller.hasBibConflicts)
                    Badge(
                      label: const Text('Issues'),
                      child: IconButton(
                        icon: const Icon(Icons.warning_amber),
                        onPressed: () => _continueRaceFlow(),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: results.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final result = results[index];
                  final hasError = result['error'] != null;
                  
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: hasError 
                            ? Colors.red.shade100 
                            : Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${result['place'] ?? '?'}',
                        style: TextStyle(
                          color: hasError 
                              ? Colors.red.shade800 
                              : Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(result['name'] ?? 'Unknown Runner'),
                        if (hasError)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Icon(Icons.error_outline, 
                              color: Colors.red.shade800, 
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(result['school'] ?? 'Unknown Team'),
                    trailing: Text(
                      result['time'] != null 
                          ? formatTimeFromSeconds(result['time'] as double)
                          : '--:--',
                      style: AppTypography.bodySemibold,
                    ),
                    onTap: hasError ? () => _continueRaceFlow() : null,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildFloatingActionButton() {
    final race = _controller.race;
    if (race == null) return const SizedBox.shrink();
    
    // Don't show FAB for finished races
    if (race.flowState == 'finished') return const SizedBox.shrink();
    
    return FloatingActionButton.extended(
      onPressed: _continueRaceFlow,
      label: Text(
        race.flowState == 'setup' ? 'Setup Race' :
        race.flowState == 'pre_race' ? 'Start Race' :
        race.flowState == 'post_race' ? 'Process Results' : 'Continue',
      ),
      icon: Icon(
        race.flowState == 'setup' ? Icons.people :
        race.flowState == 'pre_race' ? Icons.timer :
        race.flowState == 'post_race' ? Icons.assignment : Icons.play_arrow,
      ),
    );
  }
  
  String _getStatusText(String flowState) {
    switch (flowState) {
      case 'setup':
        return 'Setup';
      case 'pre_race':
        return 'Ready to Start';
      case 'post_race':
        return 'Race Completed';
      case 'finished':
        return 'Finalized';
      default:
        return 'Unknown';
    }
  }
  
  /// Format time value (in seconds) to display string
  String formatTimeFromSeconds(double seconds) {
    final int mins = (seconds / 60).floor();
    final int secs = (seconds % 60).floor();
    final int tenths = ((seconds * 10) % 10).floor();
    
    return '$mins:${secs.toString().padLeft(2, '0')}.${tenths}';
  }
}