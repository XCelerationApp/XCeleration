import 'package:flutter/material.dart';
import '../../../core/components/button_components.dart';

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.text,
    required this.onPressed,
  });
  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      text: text,
      onPressed: onPressed,
      icon: null,
      borderRadius: 12,
      elevation: 4,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
  }
}
