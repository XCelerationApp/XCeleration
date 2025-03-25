import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class InstructionCard extends StatelessWidget {
  final String title;
  final List<InstructionItem> instructions;
  final Color? accentColor;
  final IconData? icon;
  final bool initiallyExpanded;

  const InstructionCard({
    super.key,
    required this.title,
    required this.instructions,
    this.accentColor,
    this.icon = Icons.info_outline,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primaryColor;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: color.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          trailing: Icon(Icons.arrow_drop_down, color: color),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: instructions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InstructionItem extends StatelessWidget {
  final String number;
  final String text;
  final Color? accentColor;

  const InstructionItem({
    super.key,
    required this.number,
    required this.text,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primaryColor;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
