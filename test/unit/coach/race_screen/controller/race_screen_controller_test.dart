import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/flows/controller/flow_controller.dart';
import 'package:xceleration/coach/race_screen/controller/race_form_state.dart';
import 'package:xceleration/coach/race_screen/controller/race_screen_controller.dart';
import 'package:xceleration/coach/races_screen/controller/races_controller.dart';
import 'package:xceleration/core/services/date_picker_service.dart';
import 'package:xceleration/core/services/event_bus.dart';
import 'package:xceleration/core/services/geo_location_service.dart';
import 'package:xceleration/core/services/i_device_connection_factory.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/enums.dart' hide EventTypes;
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race.dart';

@GenerateMocks([
  MasterRace,
  RacesController,
  MasterFlowController,
  IGeoLocationService,
  IDatePickerService,
  IEventBus,
  IDeviceConnectionFactory,
])
import 'race_screen_controller_test.mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal widget tree and returns a live [BuildContext].
Future<BuildContext> _buildContext(WidgetTester tester) async {
  BuildContext? ctx;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) {
        ctx = context;
        return const SizedBox();
      },
    ),
  ));
  return ctx!;
}

// ---------------------------------------------------------------------------

void main() {
  late MockMasterRace mockMasterRace;
  late MockRacesController mockRacesController;
  late MockMasterFlowController mockFlowController;
  late MockIGeoLocationService mockGeoService;
  late MockIDatePickerService mockDatePickerService;
  late MockIEventBus mockEventBus;
  late MockIDeviceConnectionFactory mockDevicesFactory;
  late RaceController controller;

  // A fully-populated test race (flowState != FLOW_SETUP avoids the
  // checkSetupComplete→TeamsAndRunnersWidget code path in loadAllData)
  final testRace = Race(
    raceId: 1,
    raceName: 'Test Race',
    location: 'Test Location',
    raceDate: DateTime(2024, 6, 15),
    distance: 5.0,
    distanceUnit: 'mi',
    flowState: Race.FLOW_PRE_RACE,
  );

  setUp(() {
    mockMasterRace = MockMasterRace();
    mockRacesController = MockRacesController();
    mockFlowController = MockMasterFlowController();
    mockGeoService = MockIGeoLocationService();
    mockDatePickerService = MockIDatePickerService();
    mockEventBus = MockIEventBus();
    mockDevicesFactory = MockIDeviceConnectionFactory();

    // Common stubs required on almost every code path
    when(mockMasterRace.raceId).thenReturn(1);
    when(mockRacesController.canEdit).thenReturn(true);
    when(mockMasterRace.race).thenAnswer((_) async => testRace);
    when(mockMasterRace.raceRunners).thenAnswer((_) async => []);
    when(mockMasterRace.teams).thenAnswer((_) async => []);
    when(mockMasterRace.teamtoRaceRunnersMap).thenAnswer((_) async => {});
    when(mockMasterRace.updateRace(any)).thenAnswer((_) async {});
    when(mockFlowController.handleFlowNavigation(any, any))
        .thenAnswer((_) async => true);

    controller = RaceController(
      masterRace: mockMasterRace,
      parentController: mockRacesController,
      geoLocationService: mockGeoService,
      datePickerService: mockDatePickerService,
      flowController: mockFlowController,
      eventBus: mockEventBus,
      devicesFactory: mockDevicesFactory,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  // =========================================================================
  group('RaceController', () {
    // -------------------------------------------------------------------------
    group('selectDate', () {
      testWidgets('updates dateController when a date is picked',
          (tester) async {
        final ctx = await _buildContext(tester);
        final picked = DateTime(2025, 8, 20);
        when(mockDatePickerService.pickDate(any,
                initialDate: anyNamed('initialDate'),
                firstDate: anyNamed('firstDate'),
                lastDate: anyNamed('lastDate')))
            .thenAnswer((_) async => picked);

        await controller.selectDate(ctx);

        expect(controller.form.dateController.text, '2025-08-20');
      });

      testWidgets('does nothing when picker is cancelled', (tester) async {
        final ctx = await _buildContext(tester);
        when(mockDatePickerService.pickDate(any,
                initialDate: anyNamed('initialDate'),
                firstDate: anyNamed('firstDate'),
                lastDate: anyNamed('lastDate')))
            .thenAnswer((_) async => null);
        controller.form.dateController.text = 'existing';

        await controller.selectDate(ctx);

        expect(controller.form.dateController.text, 'existing');
      });
    });

    // -------------------------------------------------------------------------
    group('validateName', () {
      test('sets name error when name is empty', () {
        controller.validateName('');

        expect(controller.form.errorFor(RaceField.name), isNotNull);
      });

      test('clears name error when name is valid', () {
        controller.validateName('Valid Name');

        expect(controller.form.errorFor(RaceField.name), isNull);
      });
    });

    // -------------------------------------------------------------------------
    group('validateLocation', () {
      test('sets location error when location is empty', () {
        controller.validateLocation('');

        expect(controller.form.errorFor(RaceField.location), isNotNull);
      });

      test('clears location error when location is valid', () {
        controller.validateLocation('Some Location');

        expect(controller.form.errorFor(RaceField.location), isNull);
      });
    });

    // -------------------------------------------------------------------------
    group('validateDate', () {
      test('sets date error when date is empty', () {
        controller.validateDate('');

        expect(controller.form.errorFor(RaceField.date), isNotNull);
      });

      test('sets date error when date is invalid format', () {
        controller.validateDate('not-a-date');

        expect(controller.form.errorFor(RaceField.date), isNotNull);
      });

      test('clears date error when date is valid', () {
        controller.validateDate('2024-06-15');

        expect(controller.form.errorFor(RaceField.date), isNull);
      });
    });

    // -------------------------------------------------------------------------
    group('validateDistance', () {
      test('sets distance error when distance is empty', () {
        controller.validateDistance('');

        expect(controller.form.errorFor(RaceField.distance), isNotNull);
      });

      test('sets distance error when distance is not a number', () {
        controller.validateDistance('abc');

        expect(controller.form.errorFor(RaceField.distance), isNotNull);
      });

      test('sets distance error when distance is zero or negative', () {
        controller.validateDistance('0');

        expect(controller.form.errorFor(RaceField.distance), isNotNull);
      });

      test('clears distance error when distance is valid', () {
        controller.validateDistance('5.0');

        expect(controller.form.errorFor(RaceField.distance), isNull);
      });
    });

    // -------------------------------------------------------------------------
    group('navigateToRunnersManagement', () {
      test('sets showingRunnersManagement to true and notifies listeners', () {
        int notifyCount = 0;
        controller.addListener(() => notifyCount++);

        controller.navigateToRunnersManagement();

        expect(controller.showingRunnersManagement, isTrue);
        expect(notifyCount, greaterThanOrEqualTo(1));
      });
    });

    // -------------------------------------------------------------------------
    group('navigateToRaceDetails', () {
      testWidgets('sets showingRunnersManagement to false and refreshes data',
          (tester) async {
        final ctx = await _buildContext(tester);
        controller.navigateToRunnersManagement(); // start in runners mode

        await controller.navigateToRaceDetails(ctx);

        expect(controller.showingRunnersManagement, isFalse);
        verify(mockMasterRace.invalidateCache()).called(1);
      });
    });

    // -------------------------------------------------------------------------
    group('loadAllData', () {
      testWidgets(
          'happy path: isLoading transitions true→false, race data is populated',
          (tester) async {
        final ctx = await _buildContext(tester);
        final loadingStates = <bool>[];
        controller.addListener(() => loadingStates.add(controller.isLoading));

        await controller.loadAllData(ctx);

        // First notification: isLoading = true (loading started)
        // Final notification: isLoading = false (loading finished)
        expect(loadingStates.first, isTrue);
        expect(loadingStates.last, isFalse);
        expect(controller.isLoading, isFalse);
        expect(controller.hasError, isFalse);
        expect(controller.race, equals(testRace));
        expect(controller.raceRunners, isEmpty);
        expect(controller.teams, isEmpty);
      });

      testWidgets(
          'error path: hasError is true and isLoading is false after failure',
          (tester) async {
        final ctx = await _buildContext(tester);
        when(mockMasterRace.race)
            .thenAnswer((_) async => throw Exception('db error'));

        try {
          await controller.loadAllData(ctx);
        } catch (_) {
          // RaceController re-throws on initial load; catch here so test continues
        }

        expect(controller.hasError, isTrue);
        expect(controller.isLoading, isFalse);
        expect(controller.error, contains('db error'));
      });
    });

    // -------------------------------------------------------------------------
    group('refreshRaceData', () {
      testWidgets('isRefreshing cycles true→false and data is updated',
          (tester) async {
        // Perform initial load first so state is ready
        final ctx = await _buildContext(tester);
        await controller.loadAllData(ctx);

        final refreshingStates = <bool>[];
        controller
            .addListener(() => refreshingStates.add(controller.isRefreshing));

        await controller.refreshRaceData(ctx);

        // First notification during refresh: isRefreshing = true
        // Final notification: isRefreshing = false
        expect(refreshingStates.first, isTrue);
        expect(refreshingStates.last, isFalse);
        verify(mockMasterRace.invalidateCache())
            .called(greaterThanOrEqualTo(1));
      });

      testWidgets(
          'context not mounted: returns early without invalidating cache',
          (tester) async {
        BuildContext? ctx;
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (context) {
            ctx = context;
            return const SizedBox();
          }),
        ));
        // Unmount the widget tree so context.mounted == false
        await tester.pumpWidget(const SizedBox());

        await controller.refreshRaceData(ctx!);

        verifyNever(mockMasterRace.invalidateCache());
      });
    });

    // -------------------------------------------------------------------------
    group('saveRaceDetails', () {
      testWidgets(
          'saves via masterRace.updateRace with correct field values and refreshes race',
          (tester) async {
        final ctx = await _buildContext(tester);
        await controller.loadAllData(ctx);

        controller.form.nameController.text = 'New Name';
        controller.form.locationController.text = 'New Location';
        controller.form.dateController.text = '2024-06-15';
        controller.form.distanceController.text = '5.0';
        controller.form.unitController.text = 'mi';

        await controller.saveRaceDetails(ctx);

        // RaceService.saveRaceDetails delegates persistence to masterRace.updateRace
        verify(mockMasterRace.updateRace(any)).called(greaterThanOrEqualTo(1));
      });
    });

    // -------------------------------------------------------------------------
    group('handleFieldFocusLoss', () {
      testWidgets(
          'in setup flow: tracks change but does not autosave',
          (tester) async {
        final setupRace = Race(
          raceId: 1,
          raceName: 'Test',
          flowState: Race.FLOW_SETUP,
        );
        when(mockMasterRace.race).thenAnswer((_) async => setupRace);

        final ctx = await _buildContext(tester);
        await controller.loadAllData(ctx);

        controller.form.nameController.text = 'New Name';

        await controller.handleFieldFocusLoss(ctx, RaceField.name);

        // In setup flow — no autosave, so updateRace is NOT called
        verifyNever(mockMasterRace.updateRace(any));
      });

      testWidgets(
          'outside setup flow with unsaved changes: triggers autosave',
          (tester) async {
        // testRace has flowState = FLOW_PRE_RACE — not a setup flow
        final ctx = await _buildContext(tester);
        await controller.loadAllData(ctx);

        // Set up a valid name change so autosave succeeds
        controller.form.storeOriginalValue(
            RaceField.name, Race(raceId: 1, raceName: 'Old Name'));
        controller.form.nameController.text = 'New Name';
        // Pre-fill other required fields so saveRaceDetails doesn't fail
        controller.form.locationController.text = 'Test Location';
        controller.form.dateController.text = '2024-06-15';
        controller.form.distanceController.text = '5.0';

        await controller.handleFieldFocusLoss(ctx, RaceField.name);

        // Outside setup flow with unsaved changes — autosave triggers
        verify(mockMasterRace.updateRace(any)).called(greaterThanOrEqualTo(1));
      });
    });

    // -------------------------------------------------------------------------
    group('saveAllChanges', () {
      testWidgets('no unsaved changes: returns early without saving',
          (tester) async {
        final ctx = await _buildContext(tester);
        await controller.loadAllData(ctx);

        // No changes tracked — hasUnsavedChanges is false
        expect(controller.form.hasUnsavedChanges, isFalse);

        await controller.saveAllChanges(ctx);

        verifyNever(mockMasterRace.updateRace(any));
      });

      testWidgets('invalid field: sets error on form and does NOT save',
          (tester) async {
        final ctx = await _buildContext(tester);
        await controller.loadAllData(ctx);

        // Stage a change with an empty name (invalid)
        controller.form.nameController.text = '';
        controller.form.storeOriginalValue(
            RaceField.name, Race(raceId: 1, raceName: 'Original'));
        controller.form.trackChange(RaceField.name);
        expect(controller.form.hasUnsavedChanges, isTrue);

        await controller.saveAllChanges(ctx);

        expect(controller.form.errorFor(RaceField.name), isNotNull);
        // updateRace should NOT have been called
        verifyNever(mockMasterRace.updateRace(any));
      });

      testWidgets('valid fields: saves and clears changedFields',
          (tester) async {
        final ctx = await _buildContext(tester);
        await controller.loadAllData(ctx);

        // Stage a valid name change
        controller.form.storeOriginalValue(
            RaceField.name, Race(raceId: 1, raceName: 'Old Name'));
        controller.form.nameController.text = 'New Name';
        controller.form.trackChange(RaceField.name);

        // Also fill required fields so validation passes
        controller.form.locationController.text = 'Test Location';
        controller.form.dateController.text = '2024-06-15';
        controller.form.distanceController.text = '5.0';

        await controller.saveAllChanges(ctx);

        verify(mockMasterRace.updateRace(any)).called(greaterThanOrEqualTo(1));
        expect(controller.form.hasUnsavedChanges, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    group('saveFieldIfValid', () {
      testWidgets('invalid field: sets error and returns false',
          (tester) async {
        final ctx = await _buildContext(tester);
        await controller.loadAllData(ctx);
        controller.form.nameController.text = ''; // invalid: empty

        final result = await controller.saveFieldIfValid(ctx, RaceField.name);

        expect(result, isFalse);
        expect(controller.form.errorFor(RaceField.name), isNotNull);
        verifyNever(mockMasterRace.updateRace(any));
      });

      testWidgets('valid field: saves, stops editing, and returns true',
          (tester) async {
        final ctx = await _buildContext(tester);
        await controller.loadAllData(ctx);
        controller.form.nameController.text = 'Valid Name';
        controller.form.locationController.text = 'Test Location';
        controller.form.dateController.text = '2024-06-15';
        controller.form.distanceController.text = '5.0';
        controller.form.startEditing(RaceField.name);

        final result = await controller.saveFieldIfValid(ctx, RaceField.name);

        expect(result, isTrue);
        expect(controller.form.isEditing(RaceField.name), isFalse);
        verify(mockMasterRace.updateRace(any)).called(greaterThanOrEqualTo(1));
      });
    });

    // -------------------------------------------------------------------------
    group('updateRaceFlowState', () {
      testWidgets('updates race via masterRace and fires event via IEventBus',
          (tester) async {
        final ctx = await _buildContext(tester);
        await controller.loadAllData(ctx);

        await controller.updateRaceFlowState(ctx, Race.FLOW_SETUP_COMPLETED);

        verify(mockMasterRace.updateRace(any)).called(greaterThanOrEqualTo(1));
        verify(mockEventBus.fire(EventTypes.raceFlowStateChanged, any))
            .called(1);
      });

      testWidgets('fires event with correct raceId and newState',
          (tester) async {
        final ctx = await _buildContext(tester);
        await controller.loadAllData(ctx);

        await controller.updateRaceFlowState(ctx, Race.FLOW_POST_RACE);

        final captured =
            verify(mockEventBus.fire(captureAny, captureAny)).captured;
        expect(captured[0], EventTypes.raceFlowStateChanged);
        final data = captured[1] as Map<String, dynamic>;
        expect(data['raceId'], 1);
        expect(data['newState'], Race.FLOW_POST_RACE);
      });

      testWidgets(
          'setup → setup_completed transition triggers setup-complete dialog',
          (tester) async {
        final setupRace = Race(
          raceId: 1,
          raceName: 'Test Race',
          flowState: Race.FLOW_SETUP,
        );
        when(mockMasterRace.race).thenAnswer((_) async => setupRace);

        final ctx = await _buildContext(tester);
        await controller.loadAllData(ctx);

        await controller.updateRaceFlowState(ctx, Race.FLOW_SETUP_COMPLETED);
        await tester.pumpAndSettle();

        // The "Got it" button text confirms the setup-complete dialog was shown
        expect(find.text('Got it'), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    group('markCurrentFlowCompleted', () {
      testWidgets('calls updateRaceFlowState with completedFlowState',
          (tester) async {
        final ctx = await _buildContext(tester);
        await controller.loadAllData(ctx);

        // testRace.flowState = FLOW_PRE_RACE → completedFlowState = FLOW_PRE_RACE_COMPLETED
        await controller.markCurrentFlowCompleted(ctx);

        final captured = verify(mockMasterRace.updateRace(captureAny)).captured;
        final updatedRace = captured.last as Race;
        expect(updatedRace.flowState, Race.FLOW_PRE_RACE_COMPLETED);
      });
    });

    // -------------------------------------------------------------------------
    group('beginNextFlow', () {
      testWidgets(
          'advances to next non-completed state and calls flowController',
          (tester) async {
        final ctx = await _buildContext(tester);
        // Race in FLOW_SETUP_COMPLETED → nextFlowState = FLOW_PRE_RACE
        when(mockMasterRace.race).thenAnswer((_) async => Race(
              raceId: 1,
              raceName: 'Test Race',
              flowState: Race.FLOW_SETUP_COMPLETED,
            ));

        await controller.loadAllData(ctx);
        await controller.beginNextFlow(ctx);

        verify(mockMasterRace.updateRace(any)).called(greaterThanOrEqualTo(1));
        verify(mockFlowController.handleFlowNavigation(any, any)).called(1);
      });
    });

    // -------------------------------------------------------------------------
    group('continueRaceFlow', () {
      testWidgets('FLOW_SETUP with incomplete setup returns without advancing',
          (tester) async {
        final setupRace = Race(
          raceId: 1,
          raceName: 'Test',
          flowState: Race.FLOW_SETUP,
        );
        when(mockMasterRace.race).thenAnswer((_) async => setupRace);
        // teamtoRaceRunnersMap already stubbed to {} → checkMinimumRunnersLoaded = false

        final ctx = await _buildContext(tester);
        await controller.loadAllData(ctx);
        await controller.continueRaceFlow(ctx);

        // updateRace should NOT have been called (didn't advance)
        verifyNever(mockMasterRace.updateRace(any));
      });

      testWidgets(
          'completed state transitions to next state and calls flow nav',
          (tester) async {
        final completedRace = Race(
          raceId: 1,
          raceName: 'Test Race',
          flowState: Race.FLOW_SETUP_COMPLETED,
        );
        when(mockMasterRace.race).thenAnswer((_) async => completedRace);

        final ctx = await _buildContext(tester);
        await controller.loadAllData(ctx);
        await controller.continueRaceFlow(ctx);

        verify(mockMasterRace.updateRace(any)).called(greaterThanOrEqualTo(1));
        verify(mockFlowController.handleFlowNavigation(any, any)).called(1);
      });
    });

    // -------------------------------------------------------------------------
    group('createDevices', () {
      test('delegates to IDeviceConnectionFactory with correct args', () {
        final fakeDevices = DevicesManager(
          DeviceName.coach,
          DeviceType.browserDevice,
        );
        when(mockDevicesFactory.createDevices(
          any,
          any,
          data: anyNamed('data'),
          toSpectator: anyNamed('toSpectator'),
        )).thenReturn(fakeDevices);

        final result = controller.createDevices(
          DeviceType.browserDevice,
          deviceName: DeviceName.coach,
          data: 'test-data',
        );

        expect(result, same(fakeDevices));
        verify(mockDevicesFactory.createDevices(
          DeviceName.coach,
          DeviceType.browserDevice,
          data: 'test-data',
        )).called(1);
      });
    });

    // -------------------------------------------------------------------------
    group('getCurrentLocation', () {
      testWidgets('permission denied: does not set locationController',
          (tester) async {
        when(mockGeoService.checkPermission())
            .thenAnswer((_) async => LocationPermission.denied);
        when(mockGeoService.requestPermission())
            .thenAnswer((_) async => LocationPermission.denied);

        final ctx = await _buildContext(tester);
        await controller.getCurrentLocation(ctx);
        // Advance past the 3-second FToast timer created by showErrorDialog
        await tester.pump(const Duration(seconds: 4));

        expect(controller.form.locationController.text, isEmpty);
      });

      testWidgets('permission denied forever: does not set locationController',
          (tester) async {
        when(mockGeoService.checkPermission())
            .thenAnswer((_) async => LocationPermission.deniedForever);

        final ctx = await _buildContext(tester);
        await controller.getCurrentLocation(ctx);
        // Advance past the 3-second FToast timer created by showErrorDialog
        await tester.pump(const Duration(seconds: 4));

        expect(controller.form.locationController.text, isEmpty);
      });

      testWidgets('location services disabled: does not set locationController',
          (tester) async {
        when(mockGeoService.checkPermission())
            .thenAnswer((_) async => LocationPermission.whileInUse);
        when(mockGeoService.isLocationServiceEnabled())
            .thenAnswer((_) async => false);

        final ctx = await _buildContext(tester);
        await controller.getCurrentLocation(ctx);
        // Advance past the 3-second FToast timer created by showErrorDialog
        await tester.pump(const Duration(seconds: 4));

        expect(controller.form.locationController.text, isEmpty);
      });

      testWidgets('success: sets locationController with formatted address',
          (tester) async {
        when(mockGeoService.checkPermission())
            .thenAnswer((_) async => LocationPermission.whileInUse);
        when(mockGeoService.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeoService.getCurrentPosition())
            .thenAnswer((_) async => Position(
                  latitude: 37.7749,
                  longitude: -122.4194,
                  timestamp: DateTime(2024, 6, 15),
                  accuracy: 10.0,
                  altitude: 0.0,
                  heading: 0.0,
                  speed: 0.0,
                  speedAccuracy: 0.0,
                  altitudeAccuracy: 0.0,
                  headingAccuracy: 0.0,
                ));
        when(mockGeoService.placemarkFromCoordinates(any, any))
            .thenAnswer((_) async => [
                  const geocoding.Placemark(
                    subThoroughfare: '100',
                    thoroughfare: 'Main St',
                    locality: 'San Francisco',
                    administrativeArea: 'CA',
                    postalCode: '94102',
                  ),
                ]);

        final ctx = await _buildContext(tester);
        await controller.getCurrentLocation(ctx);

        expect(controller.form.locationController.text,
            '100 Main St, San Francisco, CA 94102');
      });
    });
  });
}
