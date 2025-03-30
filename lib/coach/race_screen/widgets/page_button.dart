import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';

class PageButton extends StatelessWidget {
  final String title;
  final String iconName;
  final VoidCallback onPressed;

  const PageButton({
    super.key,
    required this.title,
    required this.iconName,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (iconName) {
      case 'details':
        icon = Icons.info_outline;
        break;
      case 'runners':
        icon = Icons.people_outline;
        break;
      case 'results':
        icon = Icons.list_alt_outlined;
        break;
      default:
        icon = Icons.info_outline;
        break;
    }

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.blueGrey[700]),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTypography.bodySemibold
                  .copyWith(color: Colors.blueGrey[800]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
