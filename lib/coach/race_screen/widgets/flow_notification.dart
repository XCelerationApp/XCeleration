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
    // For completed states, show "Begin X" instead of "Continue"
    if (flowState == 'Setup Completed') {
      return 'Begin Pre-Race';
    } else if (flowState == 'Pre-Race Completed') {
      return 'Begin Post-Race';
    } else if (flowState == 'Post-Race Completed') {
      return 'Finish Race';
    } else {
      return 'Continue';
    }
  }
  
  // Get appropriate status text
  String _getStatusText() {
    if (flowState.contains('Completed')) {
      return flowState;
    } else {
      return '$flowState Not Completed';
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
