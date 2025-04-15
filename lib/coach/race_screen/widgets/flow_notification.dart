import 'package:flutter/material.dart';

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
    // For completed states, show action-specific buttons
    if (flowState == 'Setup Completed') {
      return 'Share Runner Data';
    } else if (flowState == 'Ready for Results') {
      return 'Process Results';
    } else if (flowState == 'Ready to Finalize') {
      return 'Finalize Race';
    } else {
      return 'Continue';
    }
  }
  
  // Get appropriate status text
  String _getStatusText() {
    if (flowState == 'Setup Completed') {
      return 'Ready to Share';
    } else if (flowState == 'Pre-Race Sharing Completed') {
      return 'Ready for Results';
    } else if (flowState == 'Post-Race Completed') {
      return 'Ready to Finalize';  
    } else if (flowState == 'Setup') {
      return 'Runner Setup';
    } else if (flowState == 'Runner Setup') {
      return 'Runner Setup In Progress';
    } else if (flowState == 'Pre-Race Sharing') {
      return 'Sharing Runners';
    } else if (flowState == 'Sharing Runners') {
      return 'Sharing Runners In Progress';
    } else if (flowState == 'Post-Race') {
      return 'Processing Results';
    } else if (flowState == 'Processing Results') {
      return 'Processing Results In Progress';
    } else if (flowState.contains('Completed')) {
      return flowState.replaceAll('Completed', 'Complete');
    } else if (flowState.contains('In Progress')) {
      return flowState;
    } else {
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
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            if (flowState != 'Setup') ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
