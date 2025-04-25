import 'package:flutter/material.dart';
import '../../../core/components/button_components.dart';
import '../../../shared/models/race.dart';
import '../controller/races_controller.dart';

class ActionButton extends StatelessWidget {
  final RacesController controller;
  final bool isEditing;
  final int? raceId;

  const ActionButton(
      {required this.controller,
      this.isEditing = false,
      this.raceId,
      super.key});

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
        raceId: (isEditing && raceId != null ? raceId : 0)!,
        raceName: controller.nameController.text,
        location: '',
        raceDate: null,
        distance: 0,
        distanceUnit: 'mi',
        teams: [],
        teamColors: [],
          // location: controller.locationController.text,
          // raceDate: DateTime.parse(controller.dateController.text),
          // distance: double.parse(controller.distanceController.text),
          // distanceUnit: controller.unitController.text,
          // teams: controller.teamControllers
          //     .map((controller) => controller.text.trim())
          //     .where((text) => text.isNotEmpty)
          //     .toList(),
          // teamColors: controller.teamColors,
        flowState: 'setup',
      );
      int newRaceId = race.raceId;

      if (isEditing && raceId != null) {
        await controller.updateRace(race);
      } else {
        newRaceId = await controller.createRace(race);
      }

      // Store the result and only use context if it's still mounted
      if (context.mounted) {
        Navigator.of(context).pop(newRaceId);
      }
    } catch (e) {
      // Handle errors without using ScaffoldMessenger directly
      print('Error in race creation: $e');
      
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
      text: isEditing ? 'Save Changes' : 'Create Race',
      fontSize: 24,
      borderRadius: 16,
      onPressed: () {
        // Use the same _handleAction method for both paths to ensure consistency
        if (!isEditing) {
          _handleAction(context);
        } else {
          _handleAction(context);
        }
      },
    );
  }
}
