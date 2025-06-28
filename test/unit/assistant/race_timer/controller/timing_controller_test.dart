import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:xceleration/assistant/race_timer/controller/timing_controller.dart';
import 'package:flutter/services.dart';
import 'package:xceleration/core/utils/enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final binaryMessenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    binaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
    binaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => null,
    );
    binaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '/tmp',
    );
    // Patch fluttertoast plugin channel to suppress overlay/timer creation
    binaryMessenger.setMockMethodCallHandler(
      const MethodChannel('fluttertoast'),
      (call) async => null,
    );
  });

  group('TimingController', () {
    testWidgets('addMissingTime with offBy > 1 creates a single conflict', (WidgetTester tester) async {
      late TimingController controller;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller = TimingController();
              controller.setContext(context);
              return Container();
            },
          ),
        ),
      );
      
      // Properly start the race
      controller.changeStartTime(DateTime.now());
      controller.raceStopped = false; // Ensure race is not stopped
      
      await controller.addMissingTime(offBy: 2);
      final conflicts = controller.records.where((r) => r.type == RecordType.missingTime).toList();
      expect(conflicts.length, 1);
      expect(conflicts.first.conflict?.data?['offBy'], 2);
    });

    testWidgets('addMissingTime merges consecutive missingTime conflicts', (WidgetTester tester) async {
      late TimingController controller;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller = TimingController();
              controller.setContext(context);
              return Container();
            },
          ),
        ),
      );
      
      // Properly start the race
      controller.changeStartTime(DateTime.now());
      controller.raceStopped = false; // Ensure race is not stopped
      
      await controller.addMissingTime(offBy: 1);
      await controller.addMissingTime(offBy: 2);
      final conflicts = controller.records.where((r) => r.type == RecordType.missingTime).toList();
      expect(conflicts.length, 1);
      expect(conflicts.first.conflict?.data?['offBy'], 3);
    });

    testWidgets('removeExtraTime with offBy > 1 creates a single conflict', (WidgetTester tester) async {
      late TimingController controller;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller = TimingController();
              controller.setContext(context);
              return Container();
            },
          ),
        ),
      );
      
      // Properly start the race
      controller.changeStartTime(DateTime.now());
      controller.raceStopped = false; // Ensure race is not stopped
      
      // Add 3 times
      controller.logTime();
      controller.logTime();
      controller.logTime();
      
      // Verify we have 3 records before proceeding
      expect(controller.records.length, 3);
      
      await controller.removeExtraTime(offBy: 2);
      final conflicts = controller.records.where((r) => r.type == RecordType.extraTime).toList();
      expect(conflicts.length, 1);
      expect(conflicts.first.conflict?.data?['offBy'], 2);
    });

    testWidgets('removeExtraTime merges consecutive extraTime conflicts', (WidgetTester tester) async {
      late TimingController controller;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller = TimingController();
              controller.setContext(context);
              return Container();
            },
          ),
        ),
      );
      
      // Properly start the race
      controller.changeStartTime(DateTime.now());
      controller.raceStopped = false; // Ensure race is not stopped
      
      controller.logTime();
      controller.logTime();
      controller.logTime();
      controller.logTime(); // Add 4 times to have enough for consecutive operations
      
      // Verify we have enough records
      expect(controller.records.length, 4);
      
      await controller.removeExtraTime(offBy: 1);
      await controller.removeExtraTime(offBy: 2);
      final conflicts = controller.records.where((r) => r.type == RecordType.extraTime).toList();
      expect(conflicts.length, 1);
      expect(conflicts.first.conflict?.data?['offBy'], 3);
    });

    testWidgets('undoLastConflict removes last conflict', (WidgetTester tester) async {
      late TimingController controller;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller = TimingController();
              controller.setContext(context);
              return Container();
            },
          ),
        ),
      );
      
      // Properly start the race
      controller.changeStartTime(DateTime.now());
      controller.raceStopped = false; // Ensure race is not stopped
      
      await controller.addMissingTime(offBy: 2);
      var conflicts = controller.records.where((r) => r.type == RecordType.missingTime).toList();
      expect(conflicts.length, 1);
      controller.undoLastConflict();
      conflicts = controller.records.where((r) => r.type == RecordType.missingTime).toList();
      expect(conflicts.length, 0);
    });

    testWidgets('confirmTimes adds confirmation record', (WidgetTester tester) async {
      late TimingController controller;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller = TimingController();
              controller.setContext(context);
              return Container();
            },
          ),
        ),
      );
      
      // Properly start the race
      controller.changeStartTime(DateTime.now());
      controller.raceStopped = false; // Ensure race is not stopped
      
      controller.logTime();
      
      // Verify we have at least one record before confirming
      expect(controller.records.length, 1);
      
      controller.confirmTimes();
      
      // Should now have 2 records: the original time + confirmation
      expect(controller.records.length, 2);
      final last = controller.records.last;
      expect(last.type, RecordType.confirmRunner);
    });

    testWidgets('removeExtraTime does not allow removing confirmed times', (WidgetTester tester) async {
      late TimingController controller;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller = TimingController();
              controller.setContext(context);
              return Container();
            },
          ),
        ),
      );
      
      // Properly start the race
      controller.changeStartTime(DateTime.now());
      controller.raceStopped = false; // Ensure race is not stopped
      
      controller.logTime();
      controller.logTime(); // Add a second time to have something to remove
      controller.confirmTimes();
      
      // Verify we have records and at least one confirmed
      expect(controller.records.length, greaterThan(1));
      final confirmedBefore = controller.records.where((r) => r.isConfirmed == true).toList();
      expect(confirmedBefore.length, greaterThan(0));
      
      // Try to remove 1 extra time (should not remove confirmed)
      await controller.removeExtraTime(offBy: 1);
      
      // Pump and settle to handle any pending animations/timers from the error dialog
      await tester.pumpAndSettle();
      
      // The confirmed time should still be present
      final confirmedAfter = controller.records.where((r) => r.isConfirmed == true).toList();
      expect(confirmedAfter.length, confirmedBefore.length);
      
      // Additional cleanup - pump a few more frames to ensure all timers complete
      await tester.pump(const Duration(seconds: 4)); // Wait longer than the toast timer
      await tester.pumpAndSettle();
    });

    test('addMissingTime does not allow before race start', () async {
      final controller = TimingController();
      // Don't set context for this test since we expect it to fail silently
      await controller.addMissingTime(offBy: 1);
      final conflicts = controller.records.where((r) => r.type == RecordType.missingTime).toList();
      expect(conflicts.length, 0);
    });

    // Additional unit tests that don't require UI context
    test('logTime fails when race not started', () {
      final controller = TimingController();
      // Don't set context - this should fail silently
      controller.logTime();
      expect(controller.records.length, 0);
    });

    test('confirmTimes fails when race not started', () {
      final controller = TimingController();
      // Don't set context - this should fail silently
      controller.confirmTimes();
      expect(controller.records.length, 0);
    });

    test('hasUndoableConflict returns false when no records', () {
      final controller = TimingController();
      expect(controller.hasUndoableConflict(), false);
    });

    test('calculateElapsedTime works with null start time', () {
      final controller = TimingController();
      final duration = Duration(minutes: 5);
      final result = controller.calculateElapsedTime(null, duration);
      expect(result, duration);
    });

    test('calculateElapsedTime works with valid start time', () {
      final controller = TimingController();
      final startTime = DateTime.now().subtract(Duration(minutes: 5));
      final result = controller.calculateElapsedTime(startTime, null);
      // Should be approximately 5 minutes (allowing for small timing differences)
      expect(result.inMinutes, inInclusiveRange(4, 5)); // Allow for execution time
    });

    // Additional tests to ensure race state is properly managed
    test('logTime works when race is properly started', () {
      final controller = TimingController();
      controller.changeStartTime(DateTime.now());
      controller.raceStopped = false; // Explicitly set race as not stopped
      
      controller.logTime();
      expect(controller.records.length, 1);
      expect(controller.records.first.type, RecordType.runnerTime);
    });

    test('confirmTimes works when race is properly started', () {
      final controller = TimingController();
      controller.changeStartTime(DateTime.now());
      controller.raceStopped = false; // Explicitly set race as not stopped
      
      controller.logTime();
      expect(controller.records.length, 1);
      
      controller.confirmTimes();
      expect(controller.records.length, 2);
      expect(controller.records.last.type, RecordType.confirmRunner);
    });
  });
}
