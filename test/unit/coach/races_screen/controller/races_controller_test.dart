import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/races_screen/controller/races_controller.dart';
import 'package:xceleration/coach/races_screen/services/races_service.dart';
import 'package:xceleration/core/services/auth_service.dart';
import 'package:xceleration/core/services/color_picker_dialog_service.dart';
import 'package:xceleration/core/services/date_picker_service.dart';
import 'package:xceleration/core/services/event_bus.dart';
import 'package:xceleration/core/services/geo_location_service.dart';
import 'package:xceleration/core/services/post_frame_callback_scheduler.dart';
import 'package:xceleration/core/services/tutorial_manager.dart';
import 'package:xceleration/shared/models/database/race.dart';

@GenerateMocks([
  IRacesService,
  IAuthService,
  IEventBus,
  IGeoLocationService,
  IPostFrameCallbackScheduler,
  TutorialManager,
  IDatePickerService,
  IColorPickerDialogService,
])
import 'races_controller_test.mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

RacesController _buildController({
  required MockIRacesService racesService,
  required MockIAuthService authService,
  required MockIEventBus eventBus,
  required MockIGeoLocationService geoService,
  required MockIPostFrameCallbackScheduler postFrameScheduler,
  required MockTutorialManager tutorialManager,
  required MockIDatePickerService datePickerService,
  required MockIColorPickerDialogService colorPickerService,
  bool canEdit = true,
}) {
  return RacesController(
    racesService: racesService,
    authService: authService,
    eventBus: eventBus,
    geoLocationService: geoService,
    postFrameCallbackScheduler: postFrameScheduler,
    tutorialManager: tutorialManager,
    datePickerService: datePickerService,
    colorPickerDialogService: colorPickerService,
    canEdit: canEdit,
  );
}

Future<BuildContext> _buildContext(WidgetTester tester) async {
  BuildContext? ctx;
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (context) {
      ctx = context;
      return const SizedBox();
    }),
  ));
  return ctx!;
}

// ---------------------------------------------------------------------------

void main() {
  late MockIRacesService mockRacesService;
  late MockIAuthService mockAuthService;
  late MockIEventBus mockEventBus;
  late MockIGeoLocationService mockGeoService;
  late MockIPostFrameCallbackScheduler mockPostFrameScheduler;
  late MockTutorialManager mockTutorialManager;
  late MockIDatePickerService mockDatePickerService;
  late MockIColorPickerDialogService mockColorPickerService;
  late RacesController controller;

  setUp(() {
    mockRacesService = MockIRacesService();
    mockAuthService = MockIAuthService();
    mockEventBus = MockIEventBus();
    mockGeoService = MockIGeoLocationService();
    mockPostFrameScheduler = MockIPostFrameCallbackScheduler();
    mockTutorialManager = MockTutorialManager();
    mockDatePickerService = MockIDatePickerService();
    mockColorPickerService = MockIColorPickerDialogService();

    when(mockRacesService.loadRaces()).thenAnswer((_) async => []);
    when(mockEventBus.on(any, any))
        .thenAnswer((_) => Stream<Event>.empty().listen((_) {}));

    controller = _buildController(
      racesService: mockRacesService,
      authService: mockAuthService,
      eventBus: mockEventBus,
      geoService: mockGeoService,
      postFrameScheduler: mockPostFrameScheduler,
      tutorialManager: mockTutorialManager,
      datePickerService: mockDatePickerService,
      colorPickerService: mockColorPickerService,
    );
  });

  tearDown(() => controller.dispose());

  group('RacesController', () {
    group('loadRaces', () {
      test('populates races from service', () async {
        final races = [Race(raceName: 'State Meet'), Race(raceName: 'Regional')];
        when(mockRacesService.loadRaces()).thenAnswer((_) async => races);

        await controller.loadRaces();

        expect(controller.races, equals(races));
      });

      test('notifies listeners after loading', () async {
        var notified = false;
        controller.addListener(() => notified = true);
        when(mockRacesService.loadRaces()).thenAnswer((_) async => []);

        await controller.loadRaces();

        expect(notified, isTrue);
      });
    });

    group('validateRaceName', () {
      test('returns false and sets nameError when name is empty', () {
        controller.nameController.text = '';

        final result = controller.validateRaceName();

        expect(result, isFalse);
        expect(controller.nameError, isNotNull);
      });

      test('returns false and sets nameError when name is whitespace only', () {
        controller.nameController.text = '   ';

        final result = controller.validateRaceName();

        expect(result, isFalse);
        expect(controller.nameError, isNotNull);
      });

      test('returns true and clears nameError when name is provided', () {
        controller.nameController.text = 'State Meet';

        final result = controller.validateRaceName();

        expect(result, isTrue);
        expect(controller.nameError, isNull);
      });
    });

    group('validateRaceCreation', () {
      test('returns true when name is set', () {
        controller.nameController.text = 'My Race';
        expect(controller.validateRaceCreation(), isTrue);
      });

      test('returns false when name is empty', () {
        controller.nameController.text = '';
        expect(controller.validateRaceCreation(), isFalse);
      });
    });

    group('validateName', () {
      test('clears nameError on valid input', () {
        when(mockRacesService.validateName('State Meet')).thenReturn(null);

        controller.validateName('State Meet');

        expect(controller.nameError, isNull);
      });

      test('sets nameError on invalid input', () {
        when(mockRacesService.validateName('')).thenReturn('Please enter a race name');

        controller.validateName('');

        expect(controller.nameError, 'Please enter a race name');
      });

      test('notifies listeners', () {
        when(mockRacesService.validateName(any)).thenReturn(null);
        var notified = false;
        controller.addListener(() => notified = true);

        controller.validateName('State Meet');

        expect(notified, isTrue);
      });
    });

    group('validateLocation', () {
      test('clears locationError on valid input', () {
        when(mockRacesService.validateLocation('123 Main St')).thenReturn(null);

        controller.validateLocation('123 Main St');

        expect(controller.locationError, isNull);
      });

      test('sets locationError on invalid input', () {
        when(mockRacesService.validateLocation('')).thenReturn('Please enter a location');

        controller.validateLocation('');

        expect(controller.locationError, 'Please enter a location');
      });

      test('notifies listeners', () {
        when(mockRacesService.validateLocation(any)).thenReturn(null);
        var notified = false;
        controller.addListener(() => notified = true);

        controller.validateLocation('123 Main St');

        expect(notified, isTrue);
      });
    });

    group('validateDate', () {
      test('clears dateError on valid input', () {
        when(mockRacesService.validateDate('2024-06-15')).thenReturn(null);

        controller.validateDate('2024-06-15');

        expect(controller.dateError, isNull);
      });

      test('sets dateError on invalid input', () {
        when(mockRacesService.validateDate('')).thenReturn('Please select a date');

        controller.validateDate('');

        expect(controller.dateError, 'Please select a date');
      });

      test('notifies listeners', () {
        when(mockRacesService.validateDate(any)).thenReturn(null);
        var notified = false;
        controller.addListener(() => notified = true);

        controller.validateDate('2024-06-15');

        expect(notified, isTrue);
      });
    });

    group('validateDistance', () {
      test('clears distanceError on valid input', () {
        when(mockRacesService.validateDistance('5.0')).thenReturn(null);

        controller.validateDistance('5.0');

        expect(controller.distanceError, isNull);
      });

      test('sets distanceError on invalid input', () {
        when(mockRacesService.validateDistance('')).thenReturn('Please enter a race distance');

        controller.validateDistance('');

        expect(controller.distanceError, 'Please enter a race distance');
      });

      test('notifies listeners', () {
        when(mockRacesService.validateDistance(any)).thenReturn(null);
        var notified = false;
        controller.addListener(() => notified = true);

        controller.validateDistance('5.0');

        expect(notified, isTrue);
      });
    });

    group('addTeamField', () {
      test('appends a controller and a white color', () {
        final initialCount = controller.teamControllers.length;

        controller.addTeamField();

        expect(controller.teamControllers.length, initialCount + 1);
        expect(controller.teamColors.length, initialCount + 1);
        expect(controller.teamColors.last, Colors.white);
      });
    });

    group('updateLocationButtonVisibility', () {
      test('is false when location matches userlocation', () {
        controller.locationController.text = '123 Main St';
        controller.userlocationController.text = '123 Main St';

        controller.updateLocationButtonVisibility();

        expect(controller.isLocationButtonVisible, isFalse);
      });

      test('is true when location differs from userlocation', () {
        controller.locationController.text = 'Custom Location';
        controller.userlocationController.text = '123 Main St';

        controller.updateLocationButtonVisibility();

        expect(controller.isLocationButtonVisible, isTrue);
      });
    });

    group('resetControllers', () {
      test('clears all text fields and errors', () {
        controller.nameController.text = 'Some Race';
        controller.locationController.text = 'Somewhere';
        controller.nameError = 'name error';
        controller.locationError = 'loc error';
        controller.dateError = 'date error';
        controller.distanceError = 'dist error';
        controller.teamsError = 'teams error';

        controller.resetControllers();

        expect(controller.nameController.text, isEmpty);
        expect(controller.locationController.text, isEmpty);
        expect(controller.dateController.text, isEmpty);
        expect(controller.distanceController.text, isEmpty);
        expect(controller.nameError, isNull);
        expect(controller.locationError, isNull);
        expect(controller.dateError, isNull);
        expect(controller.distanceError, isNull);
        expect(controller.teamsError, isNull);
      });

      test('resets team controllers to exactly two entries', () {
        controller.addTeamField();
        controller.addTeamField();

        controller.resetControllers();

        expect(controller.teamControllers.length, 2);
        expect(controller.teamColors.length, 2);
      });
    });

    group('selectDate', () {
      testWidgets('updates dateController when a date is picked',
          (tester) async {
        final context = await _buildContext(tester);
        final picked = DateTime(2024, 6, 15);
        when(mockDatePickerService.pickDate(any))
            .thenAnswer((_) async => picked);

        await controller.selectDate(context);

        expect(controller.dateController.text, '2024-06-15');
        expect(controller.dateError, isNull);
      });

      testWidgets('does nothing when picker is cancelled', (tester) async {
        final context = await _buildContext(tester);
        when(mockDatePickerService.pickDate(any)).thenAnswer((_) async => null);
        controller.dateController.text = 'existing';

        await controller.selectDate(context);

        expect(controller.dateController.text, 'existing');
      });
    });

    group('showColorPicker', () {
      testWidgets('delegates to service with correct color', (tester) async {
        final context = await _buildContext(tester);
        controller.addTeamField();
        final teamController = controller.teamControllers.first;
        controller.teamColors[0] = Colors.red;

        controller.showColorPicker(context, (fn) => fn(), teamController);

        verify(mockColorPickerService.showColorPicker(
          context,
          currentColor: Colors.red,
          onColorChanged: anyNamed('onColorChanged'),
        )).called(1);
      });
    });

    group('createRace', () {
      test('delegates to service and returns the new race id', () async {
        final race = Race(raceName: 'New Race');
        when(mockRacesService.createRace(race)).thenAnswer((_) async => 42);
        when(mockRacesService.loadRaces()).thenAnswer((_) async => [race]);

        final id = await controller.createRace(race);

        expect(id, 42);
        verify(mockRacesService.createRace(race)).called(1);
      });

      test('reloads races after creation', () async {
        final race = Race(raceName: 'New Race');
        when(mockRacesService.createRace(race)).thenAnswer((_) async => 1);
        final updated = [race];
        when(mockRacesService.loadRaces()).thenAnswer((_) async => updated);

        await controller.createRace(race);

        expect(controller.races, equals(updated));
      });
    });

    group('updateRace', () {
      test('delegates to service', () async {
        final race = Race(raceName: 'Updated Race', raceId: 1);
        when(mockRacesService.updateRace(race)).thenAnswer((_) async {});
        when(mockRacesService.loadRaces()).thenAnswer((_) async => [race]);

        await controller.updateRace(race);

        verify(mockRacesService.updateRace(race)).called(1);
      });

      test('reloads races after update', () async {
        final race = Race(raceName: 'Updated Race', raceId: 1);
        when(mockRacesService.updateRace(race)).thenAnswer((_) async {});
        final updated = [race];
        when(mockRacesService.loadRaces()).thenAnswer((_) async => updated);

        await controller.updateRace(race);

        expect(controller.races, equals(updated));
      });
    });

    group('editRace', () {
      testWidgets('throws when raceId is null', (tester) async {
        final context = await _buildContext(tester);
        final race = Race(raceName: 'No ID Race');

        expect(
          () => controller.editRace(race, context),
          throwsException,
        );
      });

      testWidgets('returns early without navigating when user is not owner',
          (tester) async {
        final context = await _buildContext(tester);
        when(mockAuthService.currentUserId).thenReturn('user-1');
        final race =
            Race(raceName: 'Owned Race', raceId: 1, ownerUserId: 'user-2');

        await controller.editRace(race, context);
        // Drain the 3-second overlay notification timer
        await tester.pump(const Duration(seconds: 4));

        // No service call proves we returned early
        verifyNever(mockRacesService.loadRaces());
      });
    });

    group('deleteRace', () {
      testWidgets('throws when raceId is null', (tester) async {
        final context = await _buildContext(tester);
        final race = Race(raceName: 'No ID Race');

        expect(
          () => controller.deleteRace(race, context),
          throwsException,
        );
      });

      testWidgets('returns early without deleting when user is not owner',
          (tester) async {
        final context = await _buildContext(tester);
        when(mockAuthService.currentUserId).thenReturn('user-1');
        final race =
            Race(raceName: 'Owned Race', raceId: 1, ownerUserId: 'user-2');

        await controller.deleteRace(race, context);
        // Drain the 3-second overlay notification timer
        await tester.pump(const Duration(seconds: 4));

        verifyNever(mockRacesService.deleteRace(any));
      });
    });

    group('getCurrentLocation', () {
      testWidgets('shows error when permission is permanently denied',
          (tester) async {
        final context = await _buildContext(tester);
        when(mockGeoService.checkPermission())
            .thenAnswer((_) async => LocationPermission.deniedForever);

        await controller.getCurrentLocation(context);
        await tester.pump(const Duration(seconds: 4));

        expect(controller.locationController.text, isEmpty);
      });

      testWidgets('shows error when permission is denied after request',
          (tester) async {
        final context = await _buildContext(tester);
        when(mockGeoService.checkPermission())
            .thenAnswer((_) async => LocationPermission.denied);
        when(mockGeoService.requestPermission())
            .thenAnswer((_) async => LocationPermission.denied);

        await controller.getCurrentLocation(context);
        await tester.pump(const Duration(seconds: 4));

        expect(controller.locationController.text, isEmpty);
      });

      testWidgets('shows error when location services are disabled',
          (tester) async {
        final context = await _buildContext(tester);
        when(mockGeoService.checkPermission())
            .thenAnswer((_) async => LocationPermission.whileInUse);
        when(mockGeoService.isLocationServiceEnabled())
            .thenAnswer((_) async => false);

        await controller.getCurrentLocation(context);
        await tester.pump(const Duration(seconds: 4));

        expect(controller.locationController.text, isEmpty);
      });

      testWidgets('updates locationController on success', (tester) async {
        final context = await _buildContext(tester);
        final position = Position(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: DateTime(2024, 1, 1),
          accuracy: 1.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
        const placemark = geocoding.Placemark(
          subThoroughfare: '100',
          thoroughfare: 'Main St',
          locality: 'San Francisco',
          administrativeArea: 'CA',
          postalCode: '94102',
        );
        when(mockGeoService.checkPermission())
            .thenAnswer((_) async => LocationPermission.whileInUse);
        when(mockGeoService.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeoService.getCurrentPosition())
            .thenAnswer((_) async => position);
        when(mockGeoService.placemarkFromCoordinates(
                position.latitude, position.longitude))
            .thenAnswer((_) async => [placemark]);

        await controller.getCurrentLocation(context);

        expect(controller.locationController.text,
            '100 Main St, San Francisco, CA 94102');
        expect(controller.locationError, isNull);
      });
    });

    group('event bus', () {
      testWidgets('reloads races when raceFlowStateChanged event fires',
          (tester) async {
        final context = await _buildContext(tester);

        void Function(Event)? capturedHandler;
        when(mockEventBus.on(any, any)).thenAnswer((invocation) {
          capturedHandler =
              invocation.positionalArguments[1] as void Function(Event);
          return Stream<Event>.empty().listen((_) {});
        });

        // Rebuild controller so we capture the subscription set in initState
        controller.dispose();
        controller = _buildController(
          racesService: mockRacesService,
          authService: mockAuthService,
          eventBus: mockEventBus,
          geoService: mockGeoService,
          postFrameScheduler: mockPostFrameScheduler,
          tutorialManager: mockTutorialManager,
          datePickerService: mockDatePickerService,
          colorPickerService: mockColorPickerService,
        );

        when(mockRacesService.loadRaces()).thenAnswer((_) async => []);
        when(mockPostFrameScheduler.addPostFrameCallback(any))
            .thenAnswer((_) {});

        controller.initState(context);
        expect(capturedHandler, isNotNull);

        // Clear loadRaces interactions from initState
        clearInteractions(mockRacesService);
        when(mockRacesService.loadRaces())
            .thenAnswer((_) async => [Race(raceName: 'Reloaded')]);

        capturedHandler!(Event(EventTypes.raceFlowStateChanged));
        await tester.pump();

        verify(mockRacesService.loadRaces()).called(1);
        expect(controller.races.first.raceName, 'Reloaded');
      });
    });
  });
}
