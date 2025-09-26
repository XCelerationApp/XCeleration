import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import '../../../core/components/button_components.dart';
import '../../../shared/models/database/race.dart';
import '../controller/races_controller.dart';

class ActionButton extends StatelessWidget {
  final RacesController controller;

  const ActionButton({
    required this.controller,
    super.key,
  });

  void _handleAction(BuildContext context) async {
    // Clear any validation errors
    controller.nameError = null;

    // For simplified creation, we only need to validate the race name
    if (!controller.validateRaceCreation()) {
      return;
    }

    try {
      // Create a race object with only the name
      final race = Race(
        raceId: 0,
        raceName: controller.nameController.text,
        location: '',
        raceDate: null, // Now nullable in database schema
        distance: 0,
        distanceUnit: 'mi',
        flowState: 'setup',
      );

      final newRaceId = await controller.createRace(race);

      // Store the result and only use context if it's still mounted
      if (context.mounted) {
        Navigator.of(context).pop(newRaceId);
      }
    } catch (e) {
      // Handle errors without using ScaffoldMessenger directly
      Logger.d('Error in race creation: $e');

      // Only show error dialog if context is still mounted
      if (context.mounted) {
        // Use Dialog instead of SnackBar to avoid ScaffoldMessenger issues
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Error'),
            content: Text('Failed to save race: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FullWidthButton(
      text: 'Create Race',
      fontSize: 24,
      borderRadius: 16,
      onPressed: () => _handleAction(context),
    );
  }
}
