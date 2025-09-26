import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';

class ResolveConflictButton extends StatelessWidget {
  final bool isResolved;
  final Future<void> Function() onResolve;

  const ResolveConflictButton({
    super.key,
    required this.isResolved,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isResolved ? onResolve : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isResolved ? AppColors.primaryColor : Colors.grey[400],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: isResolved ? 2 : 0,
        ),
        child: Text(
          'Resolve Conflict',
          style: AppTypography.bodySemibold.copyWith(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
