import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/controller/bib_recorder_v2_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/manage_mode_widget.dart';

import '../../../../../unit/assistant/finish_line_roles/bib_recorder/controller/bib_recorder_v2_controller_test.mocks.dart';

void main() {
  late BibRecorderV2Controller controller;

  setUp(() {
    controller = BibRecorderV2Controller(
      storage: MockIAssistantStorageService(),
      voice: MockIVoiceRecognitionService(),
      haptic: MockIHapticFeedback(),
    );
  });

  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ManageModeWidget(controller: controller))),
      );

  testWidgets('Share Bibs asks for confirmation while entries are flagged',
      (tester) async {
    controller.addBib(101);
    controller.addBib(101);
    await pump(tester);

    await tester.tap(find.text('Share Bibs'));
    await tester.pumpAndSettle();

    expect(find.text('2 entries are still flagged'), findsOneWidget);
    expect(find.text('Share Anyway'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('2 entries are still flagged'), findsNothing);
  });
}
