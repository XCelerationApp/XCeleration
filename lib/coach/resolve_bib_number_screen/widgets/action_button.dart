import 'package:flutter/material.dart';
import '../../../core/components/button_components.dart';

class ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  const ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ToggleButton(
      text: label,
      icon: icon,
      isSelected: isSelected,
      onPressed: onPressed,
      borderRadius: 12,
      elevation: isSelected ? 3 : 1,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}