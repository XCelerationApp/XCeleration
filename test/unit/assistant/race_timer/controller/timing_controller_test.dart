// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:xceleration/assistant/race_timer/controller/timing_controller.dart';

// // void main() {
// //   TestWidgetsFlutterBinding.ensureInitialized();

//   setUpAll(() {
//     final binaryMessenger =
//         TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
//     // Mock audioplayers channels
//     binaryMessenger.setMockMethodCallHandler(
//       const MethodChannel('xyz.luan/audioplayers'),
//       (call) async => null,
//     );
//     binaryMessenger.setMockMethodCallHandler(
//       const MethodChannel('xyz.luan/audioplayers.global'),
//       (call) async => null,
//     );
//     // Mock path_provider
//     binaryMessenger.setMockMethodCallHandler(
//       const MethodChannel('plugins.flutter.io/path_provider'),
//       (call) async => '/tmp',
//     );
//     // Mock fluttertoast to avoid overlays/timers
//     binaryMessenger.setMockMethodCallHandler(
//       const MethodChannel('fluttertoast'),
//       (call) async => null,
//     );
//   });

//   group('TimingController - core logic', () {
//     test('logTime does nothing when race not started', () {
//       final controller = TimingController(enableAudio: false);
//       controller.logTime();
//       expect(controller.uiRecords.length, 0);
//     });

//     test('confirmTimes does nothing when race not started', () {
//       final controller = TimingController(enableAudio: false);
//       controller.confirmTimes();
//       expect(controller.uiRecords.length, 0);
//     });

//     test('calculateElapsedTime handles null startTime', () {
//       final controller = TimingController(enableAudio: false);
//       final d = Duration(minutes: 3);
//       expect(controller.calculateElapsedTime(null, d), d);
//     });

//     test('calculateElapsedTime with startTime returns positive duration', () {
//       final controller = TimingController(enableAudio: false);
//       final start = DateTime.now().subtract(const Duration(minutes: 2));
//       final elapsed = controller.calculateElapsedTime(start, null);
//       expect(elapsed.inMinutes, inInclusiveRange(1, 2));
//     });
//   });

//   group('TimingController - with context', () {
//     testWidgets('logTime records when race started and not stopped',
//         (tester) async {
//       late TimingController controller;
//       await tester.pumpWidget(
//         MaterialApp(
//           home: Builder(
//             builder: (context) {
//               controller = TimingController(enableAudio: false);
//               controller.setContext(context);
//               controller.changeStartTime(DateTime.now());
//               controller.raceStopped = false;
//               return const SizedBox.shrink();
//             },
//           ),
//         ),
//       );

//       controller.logTime();
//       expect(controller.uiRecords.length, 1);
//     });

//     testWidgets('confirmTimes adds a confirm record when race active',
//         (tester) async {
//       late TimingController controller;
//       await tester.pumpWidget(
//         MaterialApp(
//           home: Builder(
//             builder: (context) {
//               controller = TimingController(enableAudio: false);
//               controller.setContext(context);
//               controller.changeStartTime(DateTime.now());
//               controller.raceStopped = false;
//               return const SizedBox.shrink();
//             },
//           ),
//         ),
//       );

//       controller.logTime();
//       controller.confirmTimes();
//       expect(controller.uiRecords.length, 2);
//     });

//     testWidgets('addMissingTime adds missing conflict when race started',
//         (tester) async {
//       late TimingController controller;
//       await tester.pumpWidget(
//         MaterialApp(
//           home: Builder(
//             builder: (context) {
//               controller = TimingController(enableAudio: false);
//               controller.setContext(context);
//               controller.changeStartTime(DateTime.now());
//               controller.raceStopped = false;
//               return const SizedBox.shrink();
//             },
//           ),
//         ),
//       );

//       await controller.addMissingTime();
//       expect(controller.uiRecords.isNotEmpty, true);
//     });

//     testWidgets('removeExtraTime adds extra conflict when race active',
//         (tester) async {
//       late TimingController controller;
//       await tester.pumpWidget(
//         MaterialApp(
//           home: Builder(
//             builder: (context) {
//               controller = TimingController(enableAudio: false);
//               controller.setContext(context);
//               controller.changeStartTime(DateTime.now());
//               controller.raceStopped = false;
//               return const SizedBox.shrink();
//             },
//           ),
//         ),
//       );

//       controller.logTime();
//       controller.logTime();
//       await controller.removeExtraTime();
//       expect(controller.uiRecords.isNotEmpty, true);
//     });

//     testWidgets('startRace initializes new race when no data', (tester) async {
//       late TimingController controller;
//       await tester.pumpWidget(
//         MaterialApp(
//           home: Builder(
//             builder: (context) {
//               controller = TimingController(enableAudio: false);
//               controller.setContext(context);
//               return const SizedBox.shrink();
//             },
//           ),
//         ),
//       );

//       controller.startRace();
//       expect(controller.startTime, isNotNull);
//       expect(controller.raceStopped, isFalse);
//     });

//     testWidgets('startRace prompts when data exists and confirming starts new',
//         (tester) async {
//       late TimingController controller;
//       await tester.pumpWidget(
//         MaterialApp(
//           home: Builder(
//             builder: (context) {
//               controller = TimingController(enableAudio: false);
//               controller.setContext(context);
//               controller.changeStartTime(DateTime.now());
//               controller.raceStopped = false;
//               return const SizedBox.shrink();
//             },
//           ),
//         ),
//       );

//       controller.logTime();
//       expect(controller.uiRecords.length, 1);

//       controller.startRace();
//       await tester.pump();

//       expect(find.text('Start a New Race'), findsOneWidget);
//       expect(find.text('Yes'), findsOneWidget);

//       await tester.tap(find.text('Yes'));
//       await tester.pumpAndSettle();

//       expect(controller.uiRecords.length, 0);
//       expect(controller.startTime, isNotNull);
//       expect(controller.raceStopped, isFalse);
//     });

//     testWidgets('startRace prompts and cancel keeps existing data',
//         (tester) async {
//       late TimingController controller;
//       await tester.pumpWidget(
//         MaterialApp(
//           home: Builder(
//             builder: (context) {
//               controller = TimingController(enableAudio: false);
//               controller.setContext(context);
//               controller.changeStartTime(DateTime.now());
//               controller.raceStopped = false;
//               return const SizedBox.shrink();
//             },
//           ),
//         ),
//       );

//       controller.logTime();
//       expect(controller.uiRecords.length, 1);

//       controller.startRace();
//       await tester.pump();

//       expect(find.text('Start a New Race'), findsOneWidget);
//       await tester.tap(find.text('No'));
//       await tester.pumpAndSettle();

//       expect(controller.uiRecords.length, 1);
//       expect(controller.raceStopped, isFalse);
//     });

//     testWidgets('stopRace confirms and finalizes race', (tester) async {
//       late TimingController controller;
//       await tester.pumpWidget(
//         MaterialApp(
//           home: Builder(
//             builder: (context) {
//               controller = TimingController(enableAudio: false);
//               controller.setContext(context);
//               controller.changeStartTime(DateTime.now());
//               controller.raceStopped = false;
//               return const SizedBox.shrink();
//             },
//           ),
//         ),
//       );

//       expect(controller.endTime, isNull);
//       final stopFuture = controller.stopRace();
//       await tester.pump();

//       expect(find.text('Stop the Race'), findsOneWidget);
//       await tester.tap(find.text('Yes'));
//       await tester.pumpAndSettle();
//       await stopFuture;

//       expect(controller.raceStopped, isTrue);
//       expect(controller.endTime, isNotNull);
//     });

//     testWidgets('clearRaceTimes confirms and clears', (tester) async {
//       late TimingController controller;
//       await tester.pumpWidget(
//         MaterialApp(
//           home: Builder(
//             builder: (context) {
//               controller = TimingController(enableAudio: false);
//               controller.setContext(context);
//               controller.changeStartTime(DateTime.now());
//               controller.raceStopped = false;
//               return const SizedBox.shrink();
//             },
//           ),
//         ),
//       );

//       controller.logTime();
//       expect(controller.uiRecords.isNotEmpty, true);

//       controller.clearRaceTimes();
//       await tester.pump();

//       expect(find.text('Clear Race Times'), findsOneWidget);
//       await tester.tap(find.text('Clear'));
//       await tester.pumpAndSettle();

//       expect(controller.uiRecords.isEmpty, true);
//       expect(controller.startTime, isNull);
//       expect(controller.endTime, isNull);
//     });

//     testWidgets('handleRecordDeletion deletes unconfirmed record with confirm',
//         (tester) async {
//       late TimingController controller;
//       await tester.pumpWidget(
//         MaterialApp(
//           home: Builder(
//             builder: (context) {
//               controller = TimingController(enableAudio: false);
//               controller.setContext(context);
//               controller.changeStartTime(DateTime.now());
//               controller.raceStopped = false;
//               return const SizedBox.shrink();
//             },
//           ),
//         ),
//       );

//       controller.logTime();
//       controller.logTime();
//       expect(controller.uiRecords.length, 2);

//       final recordToDelete = controller.uiRecords.first;
//       final future = controller.handleRecordDeletion(recordToDelete);
//       await tester.pump();

//       expect(find.text('Confirm Deletion'), findsOneWidget);
//       await tester.tap(find.text('Yes'));
//       await tester.pumpAndSettle();

//       final result = await future;
//       expect(result, isTrue);
//       expect(controller.uiRecords.length, 1);
//     });

//     testWidgets('handleRecordDeletion deletes last confirm record with confirm',
//         (tester) async {
//       late TimingController controller;
//       await tester.pumpWidget(
//         MaterialApp(
//           home: Builder(
//             builder: (context) {
//               controller = TimingController(enableAudio: false);
//               controller.setContext(context);
//               controller.changeStartTime(DateTime.now());
//               controller.raceStopped = false;
//               return const SizedBox.shrink();
//             },
//           ),
//         ),
//       );

//       controller.logTime();
//       controller.confirmTimes();
//       expect(controller.uiRecords.length, 2);
//       expect(controller.uiRecords.last.type.toString().contains('confirm'),
//           isTrue);

//       final recordToDelete = controller.uiRecords.last;
//       final future = controller.handleRecordDeletion(recordToDelete);
//       await tester.pump();

//       expect(find.text('Confirm Deletion'), findsOneWidget);
//       await tester.tap(find.text('Yes'));
//       await tester.pumpAndSettle();

//       final result = await future;
//       expect(result, isTrue);
//       expect(controller.uiRecords.length, 1);
//       // Remaining should be runner time
//       expect(
//           controller.uiRecords.last.type.toString().contains('runner'), isTrue);
//     });
//   });
// }

void main() {}
