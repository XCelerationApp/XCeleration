import 'package:flutter/material.dart';
import '../../../shared/models/database/race.dart'; // Import Race model for constants
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

class FlowNotification extends StatefulWidget {
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
  State<FlowNotification> createState() => _FlowNotificationState();
}

class _FlowNotificationState extends State<FlowNotification> {
  bool _pressed = false;

  // Get appropriate button text based on the flow state
  String _getButtonText() {
    if (widget.flowState == Race.FLOW_SETUP_COMPLETED) {
      return 'Share Race';
    } else if (widget.flowState == Race.FLOW_PRE_RACE_COMPLETED) {
      return 'Process Results';
    } else {
      return 'Continue';
    }
  }

  // Get appropriate status text
  String _getStatusText() {
    // Simplified status text based on flow state
    switch (widget.flowState) {
      case Race.FLOW_SETUP:
        return 'Race Setup';
      case Race.FLOW_SETUP_COMPLETED:
        return 'Ready to Share';
      case Race.FLOW_PRE_RACE:
        return 'Sharing Race';
      case Race.FLOW_PRE_RACE_COMPLETED:
        return 'Ready for Results';
      case Race.FLOW_POST_RACE:
        return 'Processing Results';
      // case Race.FLOW_POST_RACE_COMPLETED:
      case Race.FLOW_FINISHED:
        return 'Race Complete';
      default:
        // For backward compatibility or custom states
        if (widget.flowState.contains(Race.FLOW_COMPLETED_SUFFIX)) {
          final baseState =
              widget.flowState.split(Race.FLOW_COMPLETED_SUFFIX).first;
          if (baseState == Race.FLOW_POST_RACE.split('-').first) {
            return 'Race Complete';
          }
        }
        return widget.flowState;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Text(
              _getStatusText(),
              style: AppTypography.bodySemibold.copyWith(
                color: widget.color,
              ),
            ),
            const Spacer(),
            // Don't show action button for post-race completed or finished states
            if (widget.flowState != Race.FLOW_FINISHED)
              GestureDetector(
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                onTap: widget.continueAction,
                child: AnimatedContainer(
                  duration: AppAnimations.fast,
                  curve: AppAnimations.spring,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(
                        alpha: _pressed ? AppOpacity.medium : AppOpacity.light),
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    border: Border.all(
                      color: widget.color.withValues(alpha: AppOpacity.solid),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getButtonText(),
                    style: AppTypography.smallBodySemibold.copyWith(
                      color: widget.color,
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
