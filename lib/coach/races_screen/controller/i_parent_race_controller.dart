import 'package:flutter/widgets.dart';
import '../../../shared/models/database/race.dart';

/// Minimal interface that [RaceScreenController] requires from its parent controller.
/// Typed to an interface rather than the concrete [RacesController] to allow
/// mocking in tests without pulling in the full [RacesController] dependency.
abstract interface class IParentRaceController {
  bool get canEdit;
  Future<void> loadRaces();

  /// Asks, then deletes [race]. Returns whether it was deleted.
  Future<bool> deleteRace(Race race, BuildContext context);
}
