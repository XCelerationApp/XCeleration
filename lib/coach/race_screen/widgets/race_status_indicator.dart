import 'package:flutter/material.dart';
import '../../../core/components/status_badge.dart';

/// Thin wrapper kept for backward compatibility.
/// Prefer [StatusBadge] directly for new code.
class RaceStatusIndicator extends StatelessWidget {
  final String flowState;

  const RaceStatusIndicator({
    super.key,
    required this.flowState,
  });

  @override
  Widget build(BuildContext context) => StatusBadge(flowState: flowState);
}
