import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

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
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        fixedSize: const Size(160, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: AppColors.primaryColor.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
