import 'package:flutter/material.dart';
import 'package:xcelerate/core/components/coach_mark.dart';
import '../controller/races_controller.dart';

class RaceCoachMark extends StatelessWidget {
  final Widget child;
  final RacesController controller;
  const RaceCoachMark(
      {required this.child, required this.controller, super.key});
  @override
  Widget build(BuildContext context) {
    return CoachMark(
      id: 'race_swipe_tutorial',
      tutorialManager: controller.tutorialManager,
      config: const CoachMarkConfig(
        title: 'Swipe Actions',
        description: 'Swipe right on a race to edit/delete',
        icon: Icons.swipe,
        type: CoachMarkType.general,
        backgroundColor: Color(0xFF1976D2),
      ),
      child: child,
    );
  }
}
