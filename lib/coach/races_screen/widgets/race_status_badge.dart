import 'package:flutter/material.dart';
import '../../../core/components/status_badge.dart';

/// Thin wrapper kept for backward compatibility.
/// Prefer [StatusBadge] directly for new code.
class RaceStatusBadge extends StatelessWidget {
  const RaceStatusBadge({super.key, required this.flowState});

  final String flowState;

  @override
  Widget build(BuildContext context) => StatusBadge(flowState: flowState);
}
