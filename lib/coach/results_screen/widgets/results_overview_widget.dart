import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../controller/results_screen_controller.dart';
import '../model/team_record.dart';

class ResultsOverviewWidget extends StatefulWidget {
  final ResultsScreenController controller;
  
  const ResultsOverviewWidget({
    super.key,
    required this.controller,
  });

  @override
  State<ResultsOverviewWidget> createState() => _ResultsOverviewWidgetState();
}

class _ResultsOverviewWidgetState extends State<ResultsOverviewWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final List<TeamRecord> winners = widget.controller.overallTeamResults.take(3).toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (winners.length > 1) ...[
          // Silver - 2nd place
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: MedalCircle(
                  team: winners[1],
                  baseColor: const Color(0xFFB8B8B8), // Silver base - less bright
                  contrastColor: _getContrastColor(const Color(0xFFB8B8B8)),
                  highlightColor: const Color(0xFFEEEEEE), // Silver highlight - less bright
                  shadowColor: const Color(0xFF777777), // Silver shadow - darker
                  size: 50,
                  teamInitials: _getInitials(winners[1].school),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '2nd',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],

        // Gold - 1st place (slightly larger)
        if (winners.isNotEmpty)
          Column(
            children: [
              MedalCircle(
                team: winners[0],
                baseColor: const Color(0xFFD6B100), // Gold base - less bright
                contrastColor: _getContrastColor(const Color(0xFFD6B100)),
                highlightColor: const Color(0xFFECD86F), // Gold highlight - less bright
                shadowColor: const Color(0xFF8A7000), // Gold shadow - darker
                size: 60,
                teamInitials: _getInitials(winners[0].school),
              ),
              const SizedBox(height: 2),
              Text(
                '1st',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

        if (winners.length > 2) ...[
          const SizedBox(width: 8),
          // Bronze - 3rd place
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 25),
                child: MedalCircle(
                  team: winners[2],
                  baseColor: const Color(0xFFCD7F32), // Bronze base
                  contrastColor: _getContrastColor(const Color(0xFFCD7F32)),
                  highlightColor: const Color(0xFFFFB878), // Bronze highlight 
                  shadowColor: const Color(0xFF8C5425), // Bronze shadow
                  size: 45,
                  teamInitials: _getInitials(winners[2].school),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '3rd',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // Get contrasting text color for visibility
  Color _getContrastColor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.light 
        ? Colors.grey[800]!
        : Colors.white;
  }

  // Get initials from team name (2 characters)
  String _getInitials(String teamName) {
    if (teamName.isEmpty) return '';
    
    final words = teamName.trim().split(' ');
    if (words.length == 1) {
      return teamName.substring(0, teamName.length > 2 ? 2 : teamName.length).toUpperCase();
    }
    
    // Try to get initials from first two words
    String initials = '';
    for (int i = 0; i < words.length && initials.length < 2; i++) {
      if (words[i].isNotEmpty) {
        initials += words[i][0];
      }
    }
    
    // If we don't have 2 characters yet, add from the first word
    if (initials.length < 2 && words[0].length > 1) {
      initials += words[0][1];
    }
    
    return initials.toUpperCase();
  }
}

class MedalCircle extends StatelessWidget {
  const MedalCircle({
    super.key,
    required this.team,
    required this.baseColor,
    required this.contrastColor,
    required this.highlightColor,
    required this.shadowColor,
    required this.size,
    required this.teamInitials,
  });

  final TeamRecord team;
  final Color baseColor;
  final Color contrastColor;
  final Color highlightColor;
  final Color shadowColor;
  final double size;
  final String teamInitials;

  @override
  Widget build(BuildContext context) {
    // Create a gradient border effect using nested containers
    return Container(
      width: size + 6, // Increased border size
      height: size + 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Outer gradient for the border (lighter at top-left, darker at bottom-right)
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            highlightColor,
            shadowColor,
          ],
          stops: const [0.15, 0.85], // Adjusted stops for more contrast
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35), // Increased shadow opacity
            blurRadius: 4,
            spreadRadius: 0.5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // Inner container with the medal face
      child: Center(
        child: Container(
          width: size - 1, // Slightly smaller inner circle to emphasize border
          height: size - 1,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                highlightColor,
                baseColor,
                shadowColor,
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
          child: Center(
            child: Text(
              teamInitials,
              style: TextStyle(
                color: contrastColor,
                fontSize: size > 50 ? 16 : 14,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    blurRadius: 1,
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}