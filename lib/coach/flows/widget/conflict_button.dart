import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';

class ConflictButton extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onPressed;

  const ConflictButton({
    super.key,
    required this.title,
    required this.description,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[100],
          foregroundColor: Colors.red[900],
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.red[300]!),
          ),
        ),
        onPressed: onPressed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red[900]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTypography.bodySemibold.copyWith(color: Colors.red[900]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: AppTypography.bodyRegular.copyWith(color: Colors.red[900]),
            ),
          ],
        ),
      ),
    );
  }
}
