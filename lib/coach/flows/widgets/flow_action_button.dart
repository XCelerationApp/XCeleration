import 'package:flutter/material.dart';
import '../../../core/components/button_components.dart';

class FlowActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isEnabled;

  const FlowActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return FullWidthButton(
      text: label,
      onPressed: onPressed,
      isEnabled: isEnabled,
      borderRadius: 28,
      backgroundColor: const Color(0xFFFF5722),
      fontWeight: FontWeight.w600,
    );
  }
}

// This class was renamed from ActionButton to FlowOptionButton to avoid
// naming conflicts with the new button components
class FlowOptionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  const FlowOptionButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    // Using SecondaryButton to implement the flow option button
    return SecondaryButton(
      text: label,
      onPressed: onTap,
      icon: icon,
      iconLeading: true,
      size: ButtonSize.fullWidth,
      elevation: 0,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
