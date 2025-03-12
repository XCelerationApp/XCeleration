import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:xcelerate/assistant/race_timer/timing_screen/model/timing_record.dart' show TimingRecord;
import 'package:xcelerate/utils/runner_time_functions.dart';
import '../../../utils/database_helper.dart';
import '../../flows/model/flow_model.dart';
import '../../../utils/enums.dart';
import '../../../core/components/device_connection_widget.dart';
import '../../../core/theme/typography.dart';
import '../../edit_review_screen/screen/edit_and_review_screen.dart';
import '../../runners_management_screen/screen/runners_management_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/modern_detail_row.dart';
import '../widgets/race_status_indicator.dart';
import '../widgets/bib_conflicts_sheet.dart';
import '../widgets/timing_conflicts_sheet.dart';
import '../controller/race_screen_controller.dart';
import '../../flows/controller/flow_controller.dart';
import '../../merge_conflicts_screen/model/timing_data.dart';
// import '../../../edit_review_screen/model/timing_data.dart';
import '../widgets/runner_record.dart';



class RaceScreen extends StatefulWidget {
  final int raceId;
  const RaceScreen({
    super.key, 
    required this.raceId,
  });

  @override
  RaceScreenState createState() => RaceScreenState();
}

class RaceScreenState extends State<RaceScreen> with TickerProviderStateMixin {
  late String _name = '';
  late String _location = '';
  late String _date = '';
  late double _distance = 0.0;
  late final String _distanceUnit = 'miles';
  late List<Color> _teamColors = [];
  late List<String> _teamNames = [];
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _dateController;
  late TextEditingController _distanceController;
  late AnimationController _slideController;
  bool _showDetails = false;
  bool _showRunners = false;
  bool _showResults = false;
  // Controller
  late RaceScreenController _controller;
  // UI state
  final bool _preRaceFinished = false;
  final bool _postRaceFinished = false;
  bool _raceSetup = false;
  
  @override
  void initState() {
    super.initState();
    _controller = RaceScreenController(raceId: widget.raceId);
    _controller.addListener(_updateUI);
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadRace();
  }

  void _updateUI() {
    if (!mounted) return;
    setState(() {
      // Update UI variables from controller if needed
      if (_controller.race != null) {
        _name = _controller.race!.race_name;
        _location = _controller.race!.location;
        _date = _controller.race!.race_date.toString();
        _distance = _controller.race!.distance;
        _teamColors = _controller.race!.teamColors;
        _teamNames = _controller.race!.teams;
      }
    });
  }

  Future<void> _loadRace() async {
    await _controller.loadRace();
    setState(() {
      _raceSetup = _controller.raceSetup;
    });
    _continueRaceFlow();
  }

  Future<void> _continueRaceFlow() async {
    if (_controller.race == null) return;

    switch (_controller.race!.flowState) {
      case 'setup':
        await _setupRace(_controller.raceId);
        break;
      case 'pre_race':
        await _preRaceSetup(_controller.raceId);
        break;
      case 'post_race':
        await _postRaceSetup(_controller.raceId);
        break;
      case 'finished':
        // Show completed state or results
        break;
      default:
        await _setupRace(_controller.raceId);
    }
  }

  Future<void> _checkAndStartFlow() async {
    if (_controller.race == null) return;
    
    switch (_controller.race!.flowState) {
      case 'setup':
        await _setupRace(_controller.raceId);
        break;
      case 'pre_race':
        await _preRaceSetup(_controller.raceId);
        break;
      case 'post_race':
        await _postRaceSetup(_controller.raceId);
        break;
      default:
        break;
    }
  }

  Future<void> _setupRace(int raceId) async {
    final isCompleted = await _controller.setupRace(context);

    if (isCompleted) {
      await _controller.updateRaceFlowState('pre_race');
      await _preRaceSetup(raceId);
    }
    else {
      debugPrint('Setup incomplete');
    }
  }

  Future<void> _preRaceSetup(int raceId) async {
    final isCompleted = await _controller.preRaceSetup(context);

    if (isCompleted) {
      await _controller.updateRaceFlowState('post_race');
      await _postRaceSetup(raceId);
    }
  }

  Future<void> _postRaceSetup(int raceId) async {
    debugPrint('_postRaceSetup');
    final isCompleted = await _controller.postRaceSetup(context);

    if (isCompleted) {
      await _controller.updateRaceFlowState('finished');
    }
  }




  Widget _buildModernDetailRow(String label, String value, IconData icon, {bool isMultiLine = false}) {
    return ModernDetailRow(
      label: label,
      value: value,
      icon: icon,
      isMultiLine: isMultiLine,
    );
  }

  String _getStatusText(String flowState) {
    switch (flowState) {
      case 'setup':
        return 'Setup';
      case 'pre_race':
        return 'Pre-Race';
      case 'post_race':
        return 'Post-Race';
      case 'finished':
        return 'Finished';
      default:
        return 'Unknown';
    }
  }

  Future<void> _goToEditScreen(context, timingRecords, timingData) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAndReviewScreen(timingData: timingData, raceId: _controller.raceId),
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _distanceController.dispose();
    _controller.removeListener(_updateUI);
    super.dispose();
  }

  void _goToDetailsScreen(BuildContext context) {
    setState(() {
      _showDetails = true;
    });
    _slideController.forward();
  }

  void _goToRunnersScreen(BuildContext context) {
    setState(() {
      _showRunners = true;
    });
    _slideController.forward();
  }

  void _goToResultsScreen(BuildContext context) {
    setState(() {
      _showResults = true;
    });
    _slideController.forward();
  }

  void _goBackToMainRaceScreen() {
    _slideController.reverse().then((_) {
      setState(() {
        _showRunners = false;
        _showResults = false;
        _showDetails = false;
      });
    });
  }

  Color _getStatusColor(String flowState) {
    switch (flowState) {
      case 'setup':
        return Colors.amber;
      case 'pre_race':
        return Colors.blue;
      case 'post_race':
        return Colors.purple;
      case 'finished':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String flowState) {
    switch (flowState) {
      case 'setup':
        return Icons.settings;
      case 'pre_race':
        return Icons.timer;
      case 'post_race':
        return Icons.flag;
      case 'finished':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_controller.race == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rounded header with gradient background
          Container(
            constraints: const BoxConstraints(
              minHeight: 50, // Reduced height
              maxHeight: 70, // Reduced max height
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryColor,
                  AppColors.primaryColor,
                ],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)), // Increased rounding
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), // Reduced padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sheet handle at the top
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8), // Reduced margin
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Race name
                Text(
                  _controller.race!.race_name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22, // Reduced font size
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Action button area - updated color
          Container(
            color: AppColors.primaryColor, // Using primary color instead of blue
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), // Reduced padding
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4), // Reduced padding
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: Colors.white,
                    size: 14, // Reduced icon size
                  ),
                ),
                const SizedBox(width: 8), // Reduced spacing
                const Text(
                  'Setting Up',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14, // Reduced font size
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16), // Reduced radius
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16), // Reduced radius
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _continueRaceFlow,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Reduced padding
                          child: Text(
                            'Continue',
                            style: TextStyle(
                              color: AppColors.primaryColor, // Match primary color
                              fontWeight: FontWeight.bold,
                              fontSize: 13, // Reduced font size
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Race details content
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF7F7F7),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16), // Reduced padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_controller.race != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: RaceStatusIndicator(flowState: _controller.race!.flowState),
                        ),
                      ],
                      const Text(
                        'Race Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18, // Reduced font size
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 16), // Reduced spacing
                      _buildModernDetailRow(
                        'Date',
                        _controller.race!.race_date.toString().split(' ')[0],
                        Icons.calendar_today_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildModernDetailRow(
                        'Location',
                        _controller.race!.location,
                        Icons.location_on_rounded,
                        isMultiLine: true,
                      ),
                      const SizedBox(height: 16),
                      _buildModernDetailRow(
                        'Distance',
                        '${_controller.race!.distance} ${_controller.race!.distanceUnit}',
                        Icons.straighten_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildModernDetailRow(
                        'Teams',
                        _controller.race!.teams.join(', '),
                        Icons.group_rounded,
                      ),
                      // Status section removed
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}