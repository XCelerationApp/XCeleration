import 'package:flutter/material.dart';
import 'package:xcelerate/core/theme/app_colors.dart';
import 'package:xcelerate/core/theme/typography.dart';

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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          minimumSize: const Size(240, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download_sharp, color: Colors.white, size: 18),
            const SizedBox(width: 16),
            Text('Reload Results', style: AppTypography.headerSemibold.copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
