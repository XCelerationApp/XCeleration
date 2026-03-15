import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/controller/load_results_controller.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/widgets/conflict_button.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/widgets/load_results_widget.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/widgets/reload_button.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/widgets/success_message.dart';
import 'package:xceleration/core/components/connection_components.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/enums.dart';

@GenerateMocks([LoadResultsController, DevicesManager])
import 'load_results_widget_test.mocks.dart';

// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLoadResultsController mockController;
  late MockDevicesManager mockDevices;

  void stubController({
    bool resultsLoaded = false,
    bool hasBibConflicts = false,
    bool hasTimingConflicts = false,
  }) {
    when(mockController.resultsLoaded).thenReturn(resultsLoaded);
    when(mockController.hasBibConflicts).thenReturn(hasBibConflicts);
    when(mockController.hasTimingConflicts).thenReturn(hasTimingConflicts);
  }

  setUp(() {
    mockDevices = MockDevicesManager();
    when(mockDevices.currentDeviceName).thenReturn(DeviceName.coach);
    when(mockDevices.currentDeviceType).thenReturn(DeviceType.browserDevice);
    when(mockDevices.otherDevices).thenReturn([]);

    mockController = MockLoadResultsController();
    when(mockController.addListener(any)).thenReturn(null);
    when(mockController.removeListener(any)).thenReturn(null);
    when(mockController.devices).thenReturn(mockDevices);
    stubController();
  });

  Widget buildWidget() {
    return MaterialApp(
      home: Scaffold(
        body: LoadResultsWidget(controller: mockController),
      ),
    );
  }

  // =========================================================================
  group('LoadResultsWidget', () {
    // -----------------------------------------------------------------------
    testWidgets('always renders device connection widget', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(find.byType(WirelessConnectionWidget), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    group('when resultsLoaded is false', () {
      setUp(() => stubController(resultsLoaded: false));

      testWidgets('does not show SuccessMessage', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(find.byType(SuccessMessage), findsNothing);
      });

      testWidgets('does not show ConflictButton', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(find.byType(ConflictButton), findsNothing);
      });

      testWidgets('does not show ReloadButton', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(find.byType(ReloadButton), findsNothing);
      });
    });

    // -----------------------------------------------------------------------
    group('when resultsLoaded is true with no conflicts', () {
      setUp(() => stubController(resultsLoaded: true));

      testWidgets('shows SuccessMessage', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(find.byType(SuccessMessage), findsOneWidget);
      });

      testWidgets('does not show ConflictButton', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(find.byType(ConflictButton), findsNothing);
      });

      testWidgets('shows ReloadButton', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(find.byType(ReloadButton), findsOneWidget);
      });
    });

    // -----------------------------------------------------------------------
    testWidgets('shows ConflictButton when hasBibConflicts is true',
        (tester) async {
      stubController(resultsLoaded: true, hasBibConflicts: true);

      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(find.byType(ConflictButton), findsOneWidget);
      expect(find.byType(SuccessMessage), findsNothing);
    });

    testWidgets('shows ConflictButton when hasTimingConflicts is true',
        (tester) async {
      stubController(resultsLoaded: true, hasTimingConflicts: true);

      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(find.byType(ConflictButton), findsOneWidget);
      expect(find.byType(SuccessMessage), findsNothing);
    });

    testWidgets('shows ReloadButton when resultsLoaded is true',
        (tester) async {
      stubController(resultsLoaded: true);

      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(find.byType(ReloadButton), findsOneWidget);
    });

    testWidgets('does not show ReloadButton when resultsLoaded is false',
        (tester) async {
      stubController(resultsLoaded: false);

      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(find.byType(ReloadButton), findsNothing);
    });
  });
}
