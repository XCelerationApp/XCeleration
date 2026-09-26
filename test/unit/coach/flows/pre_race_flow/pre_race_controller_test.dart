import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/flows/pre_race_flow/controller/pre_race_controller.dart';
import 'package:xceleration/coach/flows/pre_race_flow/steps/share_race/share_race_step.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/coach/race_screen/services/i_race_service.dart';
import 'package:xceleration/coach/race_screen/services/race_service.dart';
import 'package:xceleration/core/services/service_locator.dart';

@GenerateMocks([MasterRace])
import 'pre_race_controller_test.mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PreRaceController _buildController(
  MockMasterRace mockMasterRace, {
  Future<String> Function(MasterRace)? encodeRaceData,
  Future<String> Function(MasterRace)? encodeBibData,
  DevicesManager? devices,
  ShowFlowFn? showFlowFn,
}) {
  return PreRaceController(
    masterRace: mockMasterRace,
    devices: devices ??
        DevicesManager(DeviceName.coach, DeviceType.advertiserDevice, data: ''),
    encodeRaceData: encodeRaceData,
    encodeBibData: encodeBibData,
    showFlowFn: showFlowFn,
  );
}

void _stubCheckRunners(MockMasterRace mockMasterRace) {
  when(mockMasterRace.teams).thenAnswer((_) async => []);
  when(mockMasterRace.raceRunners).thenAnswer((_) async => []);
}

// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMasterRace mockMasterRace;
  late DevicesManager devices;

  setUp(() {
    ServiceLocator.register<IRaceService>(RaceService());
    mockMasterRace = MockMasterRace();
    _stubCheckRunners(mockMasterRace);
    devices =
        DevicesManager(DeviceName.coach, DeviceType.advertiserDevice, data: '');
  });

  tearDown(() {
    ServiceLocator.restoreDefault();
  });

  // =========================================================================
  group('PreRaceController', () {
    // -----------------------------------------------------------------------
    group('_initializeSteps', () {
      test('is just the send page: the coach confirmed they were ready',
          () {
        final controller =
            _buildController(mockMasterRace, devices: devices);

        final steps = controller.buildSteps();

        expect(steps.single, isA<ShareRaceStep>());
      });
    });

    // -----------------------------------------------------------------------
    group('showPreRaceFlow', () {
      testWidgets('sends the roster as it is each time it opens',
          (tester) async {
        // Closed, a runner added, then opened again: the assistants must get
        // the roster with that runner.
        var roster = 'roster-before';
        final starts = <int>[];
        Future<bool> close({
          required BuildContext context,
          required List<FlowStep> steps,
          bool showProgressIndicator = true,
          int initialIndex = 0,
          StepChangedCallback? onStepChanged,
          void Function(int lastIndex)? onDismiss,
        }) async {
          starts.add(initialIndex);
          onDismiss?.call(0);
          return false;
        }

        final controller = _buildController(
          mockMasterRace,
          devices: devices,
          encodeRaceData: (_) async => 'race',
          encodeBibData: (_) async => roster,
          showFlowFn: close,
        );
        BuildContext? ctx;
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (context) {
            ctx = context;
            return const SizedBox();
          }),
        ));
        await controller.showPreRaceFlow(ctx!, false);
        expect(devices.bibRecorder!.data, 'race---roster-before');

        roster = 'roster-after';
        await controller.showPreRaceFlow(ctx!, false);

        expect(devices.bibRecorder!.data, 'race---roster-after');
        expect(starts, [0, 0]);
      });

      testWidgets('forwards showProgressIndicator correctly', (tester) async {
        final captured = <bool>[];

        Future<bool> fakeShowFlow({
          required BuildContext context,
          required List<FlowStep> steps,
          bool showProgressIndicator = true,
          int initialIndex = 0,
          StepChangedCallback? onStepChanged,
          void Function(int lastIndex)? onDismiss,
        }) async {
          captured.add(showProgressIndicator);
          onDismiss?.call(0);
          return false;
        }

        final controller = _buildController(
          mockMasterRace,
          devices: devices,
          encodeRaceData: (_) async => 'race',
          encodeBibData: (_) async => 'roster',
          showFlowFn: fakeShowFlow,
        );

        BuildContext? ctx;
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (context) {
            ctx = context;
            return const SizedBox();
          }),
        ));

        await controller.showPreRaceFlow(ctx!, true);
        await controller.showPreRaceFlow(ctx!, false);

        expect(captured[0], isTrue);
        expect(captured[1], isFalse);
      });

      testWidgets('passes the correct steps in order', (tester) async {
        List<FlowStep>? capturedSteps;

        Future<bool> fakeShowFlow({
          required BuildContext context,
          required List<FlowStep> steps,
          bool showProgressIndicator = true,
          int initialIndex = 0,
          StepChangedCallback? onStepChanged,
          void Function(int lastIndex)? onDismiss,
        }) async {
          capturedSteps = steps;
          onDismiss?.call(0);
          return false;
        }

        final controller = _buildController(
          mockMasterRace,
          devices: devices,
          encodeRaceData: (_) async => 'race',
          encodeBibData: (_) async => 'roster',
          showFlowFn: fakeShowFlow,
        );

        BuildContext? ctx;
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (context) {
            ctx = context;
            return const SizedBox();
          }),
        ));

        await controller.showPreRaceFlow(ctx!, false);

        expect(capturedSteps, isNotNull);
        expect(capturedSteps!.single, isA<ShareRaceStep>());
      });
    });

    // -----------------------------------------------------------------------
    group('preparing what is sent', () {
      Future<bool> noFlow({
        required BuildContext context,
        required List<FlowStep> steps,
        bool showProgressIndicator = true,
        int initialIndex = 0,
        StepChangedCallback? onStepChanged,
        void Function(int lastIndex)? onDismiss,
      }) async =>
          false;

      Future<void> open(WidgetTester tester, PreRaceController controller) async {
        BuildContext? ctx;
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (context) {
            ctx = context;
            return const SizedBox();
          }),
        ));
        await controller.showPreRaceFlow(ctx!, false);
      }

      testWidgets('gives each device the race, and the Bib Recorder the roster',
          (tester) async {
        final controller = _buildController(
          mockMasterRace,
          devices: devices,
          encodeRaceData: (_) async => 'encoded_race',
          encodeBibData: (_) async => 'encoded_bib',
          showFlowFn: noFlow,
        );

        await open(tester, controller);

        expect(devices.raceTimer!.data, 'encoded_race');
        expect(devices.bibRecorder!.data, 'encoded_race---encoded_bib');
      });

      testWidgets('sends nothing when the race cannot be encoded',
          (tester) async {
        final controller = _buildController(
          mockMasterRace,
          devices: devices,
          encodeRaceData: (_) async => '',
          encodeBibData: (_) async => 'encoded_bib',
          showFlowFn: noFlow,
        );

        await open(tester, controller);

        expect(devices.raceTimer!.data, '');
        expect(devices.bibRecorder!.data, '');
      });

      testWidgets('gives the Bib Recorder nothing when the roster cannot be '
          'encoded', (tester) async {
        final controller = _buildController(
          mockMasterRace,
          devices: devices,
          encodeRaceData: (_) async => 'encoded_race',
          encodeBibData: (_) async => '',
          showFlowFn: noFlow,
        );

        await open(tester, controller);

        expect(devices.raceTimer!.data, 'encoded_race');
        expect(devices.bibRecorder!.data, '');
      });
    });
  });

  // =========================================================================
  group('showSendAgainSheet', () {
    Future<BuildContext> host(WidgetTester tester) async {
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          context = c;
          return const Scaffold();
        }),
      ));
      return context;
    }

    testWidgets('sends the race and roster as they are now', (tester) async {
      final again =
          DevicesManager(DeviceName.coach, DeviceType.advertiserDevice, data: '');
      final controller = _buildController(
        mockMasterRace,
        devices: devices,
        encodeRaceData: (_) async => 'RACE',
        encodeBibData: (_) async => 'BIBS',
      )..createDevices = () => again;
      final context = await host(tester);

      controller.showSendAgainSheet(context);
      await tester.pump();
      await tester.pump();

      expect(again.raceTimer!.data, 'RACE');
      expect(again.bibRecorder!.data, 'RACE---BIBS');
      expect(find.text('Send Race Again'), findsOneWidget);
      // The flow's own connections are left alone.
      expect(devices.raceTimer!.data, '');
    });

    testWidgets('says so and opens nothing when the race cannot be prepared',
        (tester) async {
      final controller = _buildController(
        mockMasterRace,
        devices: devices,
        encodeRaceData: (_) async => '',
        encodeBibData: (_) async => 'BIBS',
      );
      final context = await host(tester);

      await controller.showSendAgainSheet(context);
      await tester.pump();

      expect(find.text('Send Race Again'), findsNothing);
      expect(find.textContaining('Could not prepare the race'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });
  });
}
