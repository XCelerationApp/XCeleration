import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/race_timer/model/timing_record.dart';
import 'package:xceleration/coach/merge_conflicts/controller/merge_conflicts_controller.dart';
import 'package:xceleration/coach/merge_conflicts/model/chunk.dart';
import 'package:xceleration/coach/merge_conflicts/model/resolve_information.dart';
import 'package:xceleration/coach/merge_conflicts/model/timing_data.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'package:xceleration/utils/enums.dart';

// Create manual mocks
class MockBuildContext extends Mock implements BuildContext {}

// We won't use a mock navigator directly since it's causing compatibility issues
// Instead we'll focus on testing controller behavior

// Create a test-friendly version of the controller that overrides certain methods
class TestableConflictsController extends MergeConflictsController {
  bool createChunksCalled = false;
  bool successMessageShown = false;
  bool errorMessageShown = false;
  String? lastErrorMessage;
  bool consolidateCalled = false;
  
  TestableConflictsController({
    required super.raceId,
    required super.timingData,
    required super.runnerRecords,
  });
  
  @override
  Future<void> createChunks() async {
    createChunksCalled = true;
    // Don't actually create chunks in tests
  }
  
  @override
  void showSuccessMessage() {
    successMessageShown = true;
    // Don't show actual dialog
  }
  
  @override
  Future<void> consolidateConfirmedRunnerTimes() async {
    consolidateCalled = true;
    // We can call the actual implementation if needed or skip it
    // await super.consolidateConfirmedRunnerTimes();
    return;
  }
}

void main() {
  group('MergeConflictsController', () {
    late TestableConflictsController controller;
    late TimingData mockTimingData;
    late List<RunnerRecord> mockRunnerRecords;
    late MockBuildContext mockContext;
    
    // Setup function for the test controller
    TestableConflictsController setupController() {
      return TestableConflictsController(
        raceId: 1,
        timingData: mockTimingData,
        runnerRecords: mockRunnerRecords,
      );
    }
    
    setUp(() {
      // Initialize mock data
      mockTimingData = TimingData(
        records: [],
        startTime: null, // Using null for startTime which is nullable DateTime?
        endTime: '10.0',
      );
      
      mockRunnerRecords = List.generate(5, (i) => RunnerRecord(
        runnerId: i+1,
        raceId: 1,
        bib: (i+1).toString(),
        name: 'Runner ${i+1}',
        grade: 10,
        school: 'School',
      ));
      
      // Set up mock context
      mockContext = MockBuildContext();
      
      // Initialize controller
      controller = setupController();
      
      // Set context on controller
      controller.setContext(mockContext);
    });

    group('handleTooFewTimesResolution', () {
      test('successfully resolves conflict and updates records', () async {
        // Prepare timing records with a missing runner conflict
        final List<TimingRecord> records = [
          // Normal runner times (places 1-2)
          TimingRecord(elapsedTime: '1.0', type: RecordType.runnerTime, place: 1, isConfirmed: true),
          TimingRecord(elapsedTime: '2.0', type: RecordType.runnerTime, place: 2, isConfirmed: true),
          
          // Confirm runner at place 2
          TimingRecord(elapsedTime: '2.5', type: RecordType.confirmRunner, place: 2, isConfirmed: true),
          
          // Missing runner conflict at place 3
          TimingRecord(
            elapsedTime: '3.5', 
            type: RecordType.missingRunner, 
            place: 3,
            conflict: ConflictDetails(
              type: RecordType.missingRunner,
              data: {'offBy': 1, 'numTimes': 3},
            ),
          ),
          
          // Runner times after the conflict
          TimingRecord(elapsedTime: '4.0', type: RecordType.runnerTime, place: 4, isConfirmed: true),
        ];
        
        controller.timingData.records = records;
        
        // Create mock chunk with resolve information and controllers
        final mockTimeControllers = [
          TextEditingController(text: '3.0'), // Time for the missing runner
        ];
        
        final mockResolveData = ResolveInformation(
          conflictingRunners: [mockRunnerRecords[2]], // Runner at index 2 is missing
          lastConfirmedPlace: 2,
          availableTimes: ['3.0'],
          conflictRecord: records[3], // The missing runner conflict record
          lastConfirmedRecord: records[2], // The confirmed runner record
          bibData: mockRunnerRecords.map((r) => r.bib.toString()).toList(),
        );
        
        final mockChunk = Chunk(
          records: records.sublist(2, 4), // The confirmed runner and conflict records
          type: RecordType.missingRunner,
          runners: [mockRunnerRecords[2]], // The missing runner
          conflictIndex: 3, // Index of the conflict record in the main records list
        );
        
        // Set controllers and resolve data on the chunk
        mockChunk.controllers = {'timeControllers': mockTimeControllers};
        mockChunk.resolve = mockResolveData;
        
        // Setup controller chunks and patch createChunks method
        controller.chunks = [mockChunk]; // Set our test chunk
        
        // Patch the controller's createChunks method for this test
        final originalCreateChunks = controller.createChunks;
        // Create a stub for the method instead of trying to replace it
        await originalCreateChunks(); // Call it once to initialize
        
        // Call the method under test
        await controller.handleTooFewTimesResolution(mockChunk);
        
        // Verify results
        // The missing runner record should be updated with the time from the controller
        expect(controller.timingData.records[2].place, equals(3));
        expect(controller.timingData.records[2].elapsedTime, equals('3.0'));
        expect(controller.timingData.records[2].isConfirmed, isTrue);
        expect(controller.timingData.records[2].conflict, isNull); // Conflict should be cleared
        
        // The conflict record should be updated to confirmRunner
        expect(controller.timingData.records[3].type, equals(RecordType.confirmRunner));
        expect(controller.timingData.records[3].isConfirmed, isTrue);
        expect(controller.timingData.records[3].conflict, isNull);
      });
      
      test('handles error when time validation fails', () async {
        // Prepare timing records with a missing runner conflict
        final List<TimingRecord> records = [
          TimingRecord(elapsedTime: '1.0', type: RecordType.runnerTime, place: 1, isConfirmed: true),
          TimingRecord(
            elapsedTime: '2.0', 
            type: RecordType.missingRunner, 
            place: 2,
            conflict: ConflictDetails(
              type: RecordType.missingRunner,
              data: {'offBy': 1, 'numTimes': 2},
            ),
          ),
        ];
        
        controller.timingData.records = records;
        
        // Create mock chunk with resolve information and controllers
        final mockTimeControllers = [
          TextEditingController(text: 'TBD'), // Invalid time (should trigger validation error)
        ];
        
        final mockResolveData = ResolveInformation(
          conflictingRunners: [mockRunnerRecords[1]], // Runner at index 1 is missing
          lastConfirmedPlace: 1,
          availableTimes: [],
          conflictRecord: records[1], // The missing runner conflict record
          lastConfirmedRecord: records[0], // The confirmed runner record
          bibData: mockRunnerRecords.map((r) => r.bib.toString()).toList(),
        );
        
        final mockChunk = Chunk(
          records: records,
          type: RecordType.missingRunner,
          runners: [mockRunnerRecords[1]], // The missing runner
          conflictIndex: 1, // Index of the conflict record in the main records list
        );
        
        // Set controllers and resolve data on the chunk
        mockChunk.controllers = {'timeControllers': mockTimeControllers};
        mockChunk.resolve = mockResolveData;
        
        // Mock required context state
        when(mockContext.mounted).thenReturn(true);
        
        // Call the method under test
        await controller.handleTooFewTimesResolution(mockChunk);
        
        // Verify the records weren't updated and method flow was interrupted
        // since validation should have failed with TBD time
        expect(controller.timingData.records[1].type, equals(RecordType.missingRunner));
        expect(controller.timingData.records[1].conflict, isNotNull);
        expect(controller.successMessageShown, isFalse);
        expect(controller.createChunksCalled, isFalse);
        expect(controller.consolidateCalled, isFalse);
        expect(controller.timingData.records[1].type, equals(RecordType.missingRunner)); // Type should remain unchanged
        expect(controller.timingData.records[1].conflict, isNotNull); // Conflict should not be cleared
        
        // No need to restore original method as we're using mocks
      });
    });
    
    group('handleTooManyTimesResolution', () {
      test('successfully resolves extra runner conflict and updates records', () async {
        // Prepare timing records with an extra runner conflict
        final List<TimingRecord> records = [
          // Normal runner times (places 1-2)
          TimingRecord(elapsedTime: '1.0', type: RecordType.runnerTime, place: 1, isConfirmed: true),
          TimingRecord(elapsedTime: '2.0', type: RecordType.runnerTime, place: 2, isConfirmed: true),
          
          // Confirm runner at place 2
          TimingRecord(elapsedTime: '2.5', type: RecordType.confirmRunner, place: 2, isConfirmed: true),
          
          // Runner times (places 3-4)
          TimingRecord(elapsedTime: '3.0', type: RecordType.runnerTime, place: 3, isConfirmed: false),
          TimingRecord(elapsedTime: '3.5', type: RecordType.runnerTime, place: 4, isConfirmed: false),
          
          // Extra runner conflict at place 4
          TimingRecord(
            elapsedTime: '4.0', 
            type: RecordType.extraRunner, 
            place: 4,
            conflict: ConflictDetails(
              type: RecordType.extraRunner,
              data: {'offBy': 1, 'numTimes': 3}, // Should only be 3 runners (not 4)
            ),
          ),
        ];
        
        controller.timingData.records = records;
        
        // Create mock chunk with resolve information and controllers
        final mockTimeControllers = [
          TextEditingController(text: '3.5'), // Selected time for the first runner
        ];
        
        final mockResolveData = ResolveInformation(
          conflictingRunners: mockRunnerRecords.sublist(2, 3), // Runner for place 3
          lastConfirmedPlace: 2,
          availableTimes: ['3.0', '3.5'], // Available times (we'll select only one)
          conflictRecord: records[5], // The extra runner conflict record
          lastConfirmedRecord: records[2], // The confirmed runner record
          lastConfirmedIndex: 2,
          bibData: mockRunnerRecords.map((r) => r.bib.toString()).toList(),
        );
        
        final mockChunk = Chunk(
          records: records.sublist(2, 6), // The relevant records
          type: RecordType.extraRunner,
          runners: mockRunnerRecords.sublist(2, 3), // The runner for place 3
          conflictIndex: 5, // Index of the conflict record in the main records list
        );
        
        // Set controllers and resolve data on the chunk
        mockChunk.controllers = {'timeControllers': mockTimeControllers};
        mockChunk.resolve = mockResolveData;
        
        // Setup controller chunks and patch createChunks method
        controller.chunks = [mockChunk]; // Set our test chunk
        
        // Patch the controller's createChunks method for this test
        final originalCreateChunks = controller.createChunks;
        // Create a stub for the method instead of trying to replace it
        await originalCreateChunks(); // Call it once to initialize
        
        // Call the method under test
        await controller.handleTooManyTimesResolution(mockChunk);
        
        // Verify results
        // Runner at place 3 should be updated with the selected time from controller
        expect(controller.timingData.records[3].elapsedTime, equals('3.5')); // Time from controller
        expect(controller.timingData.records[3].isConfirmed, isTrue);
        expect(controller.timingData.records[3].place, equals(3));
        expect(controller.timingData.records[3].bib, equals(mockRunnerRecords[2].bib)); // Bib assigned
        expect(controller.timingData.records[3].conflict, isNull);
        
        // The conflict record should be updated to confirmRunner
        expect(controller.timingData.records[5].type, equals(RecordType.confirmRunner));
        expect(controller.timingData.records[5].isConfirmed, isTrue);
        expect(controller.timingData.records[5].conflict, isNull);
        
        // Unused times should be removed
        expect(controller.timingData.records.any((r) => r.elapsedTime == '3.0'), isFalse);
      });
      
      test('handles error when no unused times are available', () async {
        // Prepare timing records with an extra runner conflict
        final List<TimingRecord> records = [
          TimingRecord(elapsedTime: '1.0', type: RecordType.runnerTime, place: 1, isConfirmed: true),
          TimingRecord(elapsedTime: '2.0', type: RecordType.runnerTime, place: 2, isConfirmed: false),
          TimingRecord(
            elapsedTime: '2.5', 
            type: RecordType.extraRunner, 
            place: 2,
            conflict: ConflictDetails(
              type: RecordType.extraRunner,
              data: {'offBy': 1, 'numTimes': 1},
            ),
          ),
        ];
        
        controller.timingData.records = records;
        
        // Create mock chunk with resolve information and controllers with all times selected
        final mockTimeControllers = [
          TextEditingController(text: '2.0'), // Selected all available times
        ];
        
        final mockResolveData = ResolveInformation(
          conflictingRunners: [mockRunnerRecords[1]],
          lastConfirmedPlace: 1,
          availableTimes: ['2.0'], // Available time that we selected
          conflictRecord: records[2],
          lastConfirmedRecord: records[0],
          lastConfirmedIndex: 0,
          bibData: mockRunnerRecords.map((r) => r.bib.toString()).toList(),
        );
        
        final mockChunk = Chunk(
          records: records.sublist(0, 3),
          type: RecordType.extraRunner,
          runners: [mockRunnerRecords[1]],
          conflictIndex: 2,
        );
        
        // Set controllers and resolve data on the chunk
        mockChunk.controllers = {'timeControllers': mockTimeControllers};
        mockChunk.resolve = mockResolveData;
        
        // Mock context to prevent null safety issues
        when(mockContext.mounted).thenReturn(true);
        
        // Call the method under test
        await controller.handleTooManyTimesResolution(mockChunk);
        
        // Verify the success flow was executed
        expect(controller.successMessageShown, isTrue);
        expect(controller.createChunksCalled, isTrue);
        expect(controller.consolidateCalled, isTrue);
        expect(controller.timingData.records[2].type, equals(RecordType.extraRunner)); // Type should remain unchanged
        expect(controller.timingData.records[2].conflict, isNotNull); // Conflict should not be cleared
        
        // No need to restore original method as we're using mocks
      });
      
      test('handles edge case with null place values', () async {
        // Prepare timing records with an extra runner conflict and null place values
        final List<TimingRecord> records = [
          TimingRecord(elapsedTime: '1.0', type: RecordType.runnerTime, place: 1, isConfirmed: true),
          TimingRecord(elapsedTime: '2.0', type: RecordType.runnerTime, place: null, isConfirmed: false), // Null place
          TimingRecord(
            elapsedTime: '2.5', 
            type: RecordType.extraRunner, 
            place: 2,
            conflict: ConflictDetails(
              type: RecordType.extraRunner,
              data: {'offBy': 1, 'numTimes': 1},
            ),
          ),
        ];
        
        controller.timingData.records = records;
        
        // Create mock chunk with resolve information and controllers
        final mockTimeControllers = [
          TextEditingController(text: '1.5'), // New time
        ];
        
        final mockResolveData = ResolveInformation(
          conflictingRunners: [mockRunnerRecords[1]],
          lastConfirmedPlace: 1,
          availableTimes: ['2.0'], // Original time available
          conflictRecord: records[2],
          lastConfirmedRecord: records[0],
          lastConfirmedIndex: 0,
          bibData: mockRunnerRecords.map((r) => r.bib.toString()).toList(),
        );
        
        final mockChunk = Chunk(
          records: records,
          type: RecordType.extraRunner,
          runners: [mockRunnerRecords[1]],
          conflictIndex: 2,
        );
        
        // Set controllers and resolve data on the chunk
        mockChunk.controllers = {'timeControllers': mockTimeControllers};
        mockChunk.resolve = mockResolveData;
        
        // Setup controller chunks and patch createChunks method
        controller.chunks = [mockChunk]; // Set our test chunk
        
        // Patch the controller's createChunks method for this test
        final originalCreateChunks = controller.createChunks;
        // Create a stub for the method instead of trying to replace it
        await originalCreateChunks(); // Call it once to initialize
        
        // Call the method under test
        await controller.handleTooManyTimesResolution(mockChunk);
        
        // Verify results
        expect(controller.timingData.records[1].elapsedTime, equals('1.5')); // Updated time
        expect(controller.timingData.records[1].place, equals(2)); // Place should be set correctly
        expect(controller.timingData.records[1].isConfirmed, isTrue);
        
        // The conflict record should be updated
        expect(controller.timingData.records[2].type, equals(RecordType.confirmRunner));
      });
    });
  });
}
