import 'package:flutter/material.dart';
import 'package:xceleration/core/components/button_components.dart';

/// A styled button for reloading race results
class ReloadButton extends StatelessWidget {
  /// Function to call when the reload button is pressed
  final VoidCallback onPressed;

  const ReloadButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FullWidthButton(
      text: 'Reload Results',
      icon: Icons.download_sharp,
      iconSize: 18,
      onPressed: onPressed,
      borderRadius: 12,  // Less round for a cleaner look
      fontSize: 16,
      fontWeight: FontWeight.w600,
      elevation: 0.5, // Subtle shadow for modern look
    );
  }
}
