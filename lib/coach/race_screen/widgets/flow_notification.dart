import 'package:flutter/material.dart';
import '../../../shared/models/database/race.dart'; // Import Race model for constants
import '../../../core/theme/typography.dart';

class FlowNotification extends StatelessWidget {
  final String flowState;
  final Color color;
  final IconData icon;
  final VoidCallback continueAction;

  const FlowNotification(
      {super.key,
      required this.flowState,
      required this.color,
      required this.icon,
      required this.continueAction});

  // Get appropriate button text based on the flow state
  String _getButtonText() {
    if (flowState == Race.FLOW_SETUP_COMPLETED) {
      return 'Share Runner Data';
    } else if (flowState == Race.FLOW_PRE_RACE_COMPLETED) {
      return 'Process Results';
    } else {
      return 'Continue';
    }
  }

  // Get appropriate status text
  String _getStatusText() {
    // Simplified status text based on flow state
    switch (flowState) {
      case Race.FLOW_SETUP:
        return 'Race Setup';
      case Race.FLOW_SETUP_COMPLETED:
        return 'Ready to Share';
      case Race.FLOW_PRE_RACE:
        return 'Sharing Runners';
      case Race.FLOW_PRE_RACE_COMPLETED:
        return 'Ready for Results';
      case Race.FLOW_POST_RACE:
        return 'Processing Results';
      // case Race.FLOW_POST_RACE_COMPLETED:
      case Race.FLOW_FINISHED:
        return 'Race Complete';
      default:
        // For backward compatibility or custom states
        if (flowState.contains(Race.FLOW_COMPLETED_SUFFIX)) {
          final baseState = flowState.split(Race.FLOW_COMPLETED_SUFFIX).first;
          if (baseState == Race.FLOW_POST_RACE.split('-').first) {
            return 'Race Complete';
          }
        }
        return flowState;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(
              _getStatusText(),
              style: AppTypography.bodySemibold.copyWith(
                color: color,
              ),
            ),
            const Spacer(),
            // Don't show action button for post-race completed or finished states
            if (flowState != Race.FLOW_FINISHED)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withAlpha((0.5 * 255).round()),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  onTap: continueAction,
                  child: Text(
                    _getButtonText(),
                    style: AppTypography.smallBodySemibold.copyWith(
                      color: color,
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
