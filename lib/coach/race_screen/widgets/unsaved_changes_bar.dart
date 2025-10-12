import 'package:flutter/material.dart';
import '../../../shared/models/database/race.dart';
import '../controller/race_screen_controller.dart';
import '../../../core/components/button_components.dart';

class UnsavedChangesBar extends StatelessWidget {
  final RaceController controller;

  const UnsavedChangesBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Race>(
      future: controller.masterRace.race,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final race = snapshot.data!;
        // Only show during setup flow
        final bool isSetupFlow = race.flowState == Race.FLOW_SETUP ||
            race.flowState == Race.FLOW_SETUP_COMPLETED;

        if (!controller.hasUnsavedChanges || !isSetupFlow) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  text: 'Revert Changes',
                  onPressed: controller.revertAllChanges,
                  size: ButtonSize.fullWidth,
                  borderRadius: 10,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  text: 'Save Changes',
                  onPressed: () => controller.saveAllChanges(context),
                  size: ButtonSize.fullWidth,
                  borderRadius: 10,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
