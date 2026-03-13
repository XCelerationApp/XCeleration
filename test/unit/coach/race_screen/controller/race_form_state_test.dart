import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/race_screen/controller/race_form_state.dart';
import 'package:xceleration/shared/models/database/race.dart';

void main() {
  group('RaceFormState', () {
    late RaceFormState form;

    setUp(() {
      form = RaceFormState();
    });

    tearDown(() {
      form.dispose();
    });

    // -------------------------------------------------------------------------
    group('startEditing / stopEditing / isEditing', () {
      test('isEditing returns false before startEditing', () {
        expect(form.isEditing(RaceField.name), isFalse);
      });

      test('isEditing returns true after startEditing', () {
        form.startEditing(RaceField.name);
        expect(form.isEditing(RaceField.name), isTrue);
      });

      test('isEditing returns false after stopEditing', () {
        form.startEditing(RaceField.name);
        form.stopEditing(RaceField.name);
        expect(form.isEditing(RaceField.name), isFalse);
      });

      test('editing one field does not affect another', () {
        form.startEditing(RaceField.name);
        expect(form.isEditing(RaceField.location), isFalse);
      });

      test('startEditing notifies listeners', () {
        int count = 0;
        form.addListener(() => count++);
        form.startEditing(RaceField.name);
        expect(count, 1);
      });

      test('stopEditing notifies listeners', () {
        form.startEditing(RaceField.name);
        int count = 0;
        form.addListener(() => count++);
        form.stopEditing(RaceField.name);
        expect(count, 1);
      });
    });

    // -------------------------------------------------------------------------
    group('shouldShowAsEditable', () {
      final raceWithName =
          Race(raceId: 1, raceName: 'Test Race', flowState: Race.FLOW_SETUP);
      final raceEmpty =
          Race(raceId: 1, raceName: '', flowState: Race.FLOW_SETUP);
      final raceNullDate = Race(raceId: 1, flowState: Race.FLOW_SETUP);
      final raceZeroDistance =
          Race(raceId: 1, distance: 0, flowState: Race.FLOW_SETUP);

      test('returns false when canEdit is false regardless of field state', () {
        expect(form.shouldShowAsEditable(RaceField.name, raceEmpty, false),
            isFalse);
      });

      test('returns true when canEdit and currently editing', () {
        form.startEditing(RaceField.name);
        expect(form.shouldShowAsEditable(RaceField.name, raceWithName, true),
            isTrue);
      });

      test('returns true for empty name field when canEdit is true', () {
        expect(
            form.shouldShowAsEditable(RaceField.name, raceEmpty, true), isTrue);
      });

      test('returns false for non-empty name when not editing', () {
        expect(form.shouldShowAsEditable(RaceField.name, raceWithName, true),
            isFalse);
      });

      test('returns true for null date field when canEdit is true', () {
        expect(form.shouldShowAsEditable(RaceField.date, raceNullDate, true),
            isTrue);
      });

      test('returns true for zero distance when canEdit is true', () {
        expect(
            form.shouldShowAsEditable(
                RaceField.distance, raceZeroDistance, true),
            isTrue);
      });

      test('returns false for unit field always, even when canEdit is true',
          () {
        expect(form.shouldShowAsEditable(RaceField.unit, raceEmpty, true),
            isFalse);
      });
    });

    // -------------------------------------------------------------------------
    group('trackChange', () {
      final race = Race(
          raceId: 1,
          raceName: 'Original',
          location: 'Park',
          flowState: Race.FLOW_SETUP);

      setUp(() {
        form.initializeFrom(race);
      });

      test('adds field to changedFields when value differs from original', () {
        form.storeOriginalValue(RaceField.name, race);
        form.nameController.text = 'Updated';
        form.trackChange(RaceField.name);
        expect(form.changedFields, contains(RaceField.name));
      });

      test('removes field from changedFields when reverted to original', () {
        form.storeOriginalValue(RaceField.name, race);
        form.nameController.text = 'Updated';
        form.trackChange(RaceField.name);
        form.nameController.text = 'Original';
        form.trackChange(RaceField.name);
        expect(form.changedFields, isNot(contains(RaceField.name)));
      });

      test('notifies listeners on trackChange', () {
        form.storeOriginalValue(RaceField.name, race);
        int count = 0;
        form.addListener(() => count++);
        form.nameController.text = 'Updated';
        form.trackChange(RaceField.name);
        expect(count, 1);
      });
    });

    // -------------------------------------------------------------------------
    group('hasUnsavedChanges', () {
      test('returns false when no changes tracked', () {
        expect(form.hasUnsavedChanges, isFalse);
      });

      test('returns true after a changed field is tracked', () {
        final race =
            Race(raceId: 1, raceName: 'Original', flowState: Race.FLOW_SETUP);
        form.initializeFrom(race);
        form.storeOriginalValue(RaceField.name, race);
        form.nameController.text = 'Updated';
        form.trackChange(RaceField.name);
        expect(form.hasUnsavedChanges, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    group('revertField', () {
      test('restores controller text to the stored original value', () {
        final race =
            Race(raceId: 1, raceName: 'Original', flowState: Race.FLOW_SETUP);
        form.initializeFrom(race);
        form.storeOriginalValue(RaceField.name, race);
        form.nameController.text = 'Changed';

        form.revertField(RaceField.name);

        expect(form.nameController.text, 'Original');
      });

      test('does nothing when no original value has been stored', () {
        form.nameController.text = 'Changed';
        form.revertField(RaceField.name);
        expect(form.nameController.text, 'Changed');
      });
    });

    // -------------------------------------------------------------------------
    group('revertAll', () {
      test('restores all changed fields and clears changedFields', () {
        final race = Race(
            raceId: 1,
            raceName: 'Original',
            location: 'Park',
            flowState: Race.FLOW_SETUP);
        form.initializeFrom(race);
        form.storeOriginalValue(RaceField.name, race);
        form.storeOriginalValue(RaceField.location, race);
        form.nameController.text = 'New Name';
        form.locationController.text = 'New Location';
        form.trackChange(RaceField.name);
        form.trackChange(RaceField.location);

        form.revertAll();

        expect(form.nameController.text, 'Original');
        expect(form.locationController.text, 'Park');
        expect(form.hasUnsavedChanges, isFalse);
      });

      test('notifies listeners after reverting all', () {
        int count = 0;
        form.addListener(() => count++);
        form.revertAll();
        expect(count, 1);
      });
    });

    // -------------------------------------------------------------------------
    group('initializeFrom', () {
      test('populates all controllers from a fully populated race', () {
        final date = DateTime(2024, 6, 15);
        final race = Race(
          raceId: 1,
          raceName: 'State Meet',
          location: 'Central Park',
          raceDate: date,
          distance: 5.0,
          distanceUnit: 'km',
          flowState: Race.FLOW_SETUP,
        );

        form.initializeFrom(race);

        expect(form.nameController.text, 'State Meet');
        expect(form.locationController.text, 'Central Park');
        expect(form.dateController.text, '2024-06-15');
        expect(form.distanceController.text, '5.0');
        expect(form.unitController.text, 'km');
      });

      test('uses empty string for null race name', () {
        form.initializeFrom(Race(raceId: 1, flowState: Race.FLOW_SETUP));
        expect(form.nameController.text, '');
      });

      test('uses empty string for null date', () {
        form.initializeFrom(Race(raceId: 1, flowState: Race.FLOW_SETUP));
        expect(form.dateController.text, '');
      });

      test('uses empty string when distance is null or zero', () {
        form.initializeFrom(
            Race(raceId: 1, distance: 0, flowState: Race.FLOW_SETUP));
        expect(form.distanceController.text, '');
      });

      test('defaults unit to mi when distanceUnit is null', () {
        form.initializeFrom(Race(raceId: 1, flowState: Race.FLOW_SETUP));
        expect(form.unitController.text, 'mi');
      });
    });

    // -------------------------------------------------------------------------
    group('updateFrom', () {
      test('updates non-editing fields when data changes', () {
        form.initializeFrom(
            Race(raceId: 1, raceName: 'Initial', flowState: Race.FLOW_SETUP));

        form.updateFrom(
            Race(raceId: 1, raceName: 'Updated', flowState: Race.FLOW_SETUP));

        expect(form.nameController.text, 'Updated');
      });

      test('does NOT update a field that is currently being edited', () {
        form.initializeFrom(
            Race(raceId: 1, raceName: 'Initial', flowState: Race.FLOW_SETUP));
        form.startEditing(RaceField.name);
        form.nameController.text = 'User is typing...';

        form.updateFrom(
            Race(raceId: 1, raceName: 'Updated', flowState: Race.FLOW_SETUP));

        expect(form.nameController.text, 'User is typing...');
      });
    });
  });
}
