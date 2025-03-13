import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/modern_detail_row.dart';
import '../widgets/race_status_indicator.dart';
import '../controller/race_screen_controller.dart';



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
  // Controller
  late RaceScreenController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = RaceScreenController(raceId: widget.raceId);
    _controller.init(context);
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
    print('flowState: $flowState!!!');
    switch (flowState) {
      case 'setup':
        return 'Setup';
      case 'pre-race':
        return 'Pre-Race';
      case 'post-race':
        return 'Post-Race';
      case 'finished':
        return 'Finished';
      default:
        return 'Unknown';
    }
  }
  Color _getStatusColor(String flowState) {
    switch (flowState) {
      case 'setup':
        return Colors.amber;
      case 'pre-race':
        return Colors.blue;
      case 'post-race':
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
      case 'pre-race':
        return Icons.timer;
      case 'post-race':
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
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)), // Increased rounding
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
                child: Icon(
                  _getStatusIcon(_controller.race!.flowState),
                  color: _getStatusColor(_controller.race!.flowState),
                  size: 14, // Reduced icon size
                ),
              ),
              const SizedBox(width: 8), // Reduced spacing
              Text(
                _getStatusText(_controller.race!.flowState),
                style: TextStyle(
                  color: _getStatusColor(_controller.race!.flowState),
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
                      onTap: () => _controller.continueRaceFlow(context),
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
    );
  }
}