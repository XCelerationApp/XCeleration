/// Minimal interface that [RaceController] requires from its parent controller.
/// Typed to an interface rather than the concrete [RacesController] to allow
/// mocking in tests without pulling in the full [RacesController] dependency.
abstract interface class IParentRaceController {
  bool get canEdit;
  Future<void> loadRaces();
}
