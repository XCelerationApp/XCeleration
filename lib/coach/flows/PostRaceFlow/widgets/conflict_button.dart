import 'package:flutter/material.dart';
import 'package:xcelerate/core/theme/app_colors.dart';
import 'package:xcelerate/core/theme/typography.dart';

class ConflictButton extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onPressed;

  const ConflictButton({
    Key? key,
    required this.title,
    required this.description,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.bodySemibold.copyWith(color: Colors.amber.shade700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: AppTypography.bodyRegular.copyWith(color: AppColors.darkColor.withOpacity(0.8)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              minimumSize: const Size(120, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: onPressed,
            child: Text(
              'Resolve Conflicts',
              style: AppTypography.buttonText.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
