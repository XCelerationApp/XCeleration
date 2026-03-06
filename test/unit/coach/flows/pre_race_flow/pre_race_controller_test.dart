import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/flows/PreRaceFlow/controller/pre_race_controller.dart';
import 'package:xceleration/coach/flows/PreRaceFlow/steps/flow_complete/pre_race_flow_complete.dart';
import 'package:xceleration/coach/flows/PreRaceFlow/steps/review_runners/review_runners_step.dart';
import 'package:xceleration/coach/flows/PreRaceFlow/steps/share_race/share_race_step.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/database/master_race.dart';

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
}) {
  return PreRaceController(
    masterRace: mockMasterRace,
    devices: devices ??
        DevicesManager(DeviceName.coach, DeviceType.advertiserDevice, data: ''),
    encodeRaceData: encodeRaceData,
    encodeBibData: encodeBibData,
  );
}

void _stubCheckRunners(MockMasterRace mockMasterRace) {
  when(mockMasterRace.teamtoRaceRunnersMap).thenAnswer((_) async => {});
}

// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMasterRace mockMasterRace;
  late DevicesManager devices;

  setUp(() {
    mockMasterRace = MockMasterRace();
    _stubCheckRunners(mockMasterRace);
    devices =
        DevicesManager(DeviceName.coach, DeviceType.advertiserDevice, data: '');
  });

  // =========================================================================
  group('PreRaceController', () {
    // -----------------------------------------------------------------------
    group('_initializeSteps', () {
      test('builds three steps in the correct order', () {
        final controller =
            _buildController(mockMasterRace, devices: devices);

        final steps = controller.buildSteps();

        expect(steps.length, 3);
        expect(steps[0], isA<ReviewRunnersStep>());
        expect(steps[1], isA<ShareRaceStep>());
        expect(steps[2], isA<PreRaceFlowCompleteStep>());
      });
    });

    // -----------------------------------------------------------------------
    group('ReviewRunnersStep.onNext', () {
      test('assigns encoded race and bib data to devices on success', () async {
        const raceEncoded = 'encoded_race';
        const bibEncoded = 'encoded_bib';

        final controller = _buildController(
          mockMasterRace,
          devices: devices,
          encodeRaceData: (_) async => raceEncoded,
          encodeBibData: (_) async => bibEncoded,
        );

        final onNext = controller.buildSteps()[0].onNext!;
        await onNext();

        expect(devices.raceTimer!.data, raceEncoded);
        expect(
            devices.bibRecorder!.data, '$raceEncoded---$bibEncoded');
      });

      test('returns early without setting device data when race encoding is empty',
          () async {
        final controller = _buildController(
          mockMasterRace,
          devices: devices,
          encodeRaceData: (_) async => '',
          encodeBibData: (_) async => 'encoded_bib',
        );

        final onNext = controller.buildSteps()[0].onNext!;
        await onNext();

        expect(devices.raceTimer!.data, '');
        expect(devices.bibRecorder!.data, '');
      });

      test('returns early without setting bib data when bib encoding is empty',
          () async {
        const raceEncoded = 'encoded_race';

        final controller = _buildController(
          mockMasterRace,
          devices: devices,
          encodeRaceData: (_) async => raceEncoded,
          encodeBibData: (_) async => '',
        );

        final onNext = controller.buildSteps()[0].onNext!;
        await onNext();

        expect(devices.raceTimer!.data, raceEncoded);
        expect(devices.bibRecorder!.data, '');
      });
    });
  });
}
