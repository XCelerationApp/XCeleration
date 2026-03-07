import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    group('editRace', () {
      testWidgets('throws when raceId is null', (tester) async {
        final context = await _buildContext(tester);
        final race = Race(raceName: 'No ID Race');

        expect(
          () => controller.editRace(race, context),
          throwsException,
        );
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
    });
  });
}
