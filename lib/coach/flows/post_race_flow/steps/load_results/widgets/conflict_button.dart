import 'package:flutter/material.dart';
import '../../../../../../core/components/race_components.dart'
    as race_components;

class ConflictButton extends StatelessWidget {
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onPressed;

  const ConflictButton({
    super.key,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return race_components.ConflictButton(
      title: title,
      subtitle: description,
      icon: Icons.warning_amber_rounded,
      color: Colors.amber.shade700,
      onPressed: onPressed,
    );
  }
}

/// Alias for the shared ConflictButton to avoid naming conflicts
typedef SharedConflictButton = ConflictButton;
