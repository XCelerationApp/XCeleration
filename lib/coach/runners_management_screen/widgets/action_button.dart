import 'package:flutter/material.dart';
import '../../../core/components/button_components.dart';

class ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;

  const ActionButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      text: text,
      onPressed: onPressed,
      icon: icon,
      size: ButtonSize.medium,
      borderRadius: 10,
    );
  }
}
