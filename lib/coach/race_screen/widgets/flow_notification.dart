import 'package:flutter/material.dart';
// import '../../../core/theme/app_colors.dart';

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            Text(
              '$flowState Not Completed',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                  'Continue',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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
