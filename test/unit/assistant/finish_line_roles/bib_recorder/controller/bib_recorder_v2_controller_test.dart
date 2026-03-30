import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/i_voice_recognition_service.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/controller/bib_recorder_v2_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
import 'package:xceleration/assistant/shared/models/bib_record.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/haptic_feedback_service.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

import 'bib_recorder_v2_controller_test.mocks.dart';

@GenerateMocks([
  IAssistantStorageService,
  IVoiceRecognitionService,
  IHapticFeedback,
  P2PSessionService,
])
void main() {
  setUpAll(() {
    // Mockito cannot auto-generate dummies for sealed Result<T> types.
    provideDummy<Result<void>>(
        Failure<void>(const AppError(userMessage: '')));
    provideDummy<Result<List<RaceRecord>>>(const Success([]));
    provideDummy<Result<List<Runner>>>(const Success([]));
    provideDummy<Result<List<BibRecord>>>(const Success([]));
    provideDummy<Result<TimingChunk?>>(const Success(null));
    provideDummy<Result<List<TimingChunk>>>(const Success([]));
    provideDummy<Result<String?>>(const Success(null));
    provideDummy<Result<int>>(const Success(0));
  });

  late MockP2PSessionService mockSession;
  late StreamController<(Role, MessageEnvelope)> incomingController;

  setUp(() {
    mockSession = MockP2PSessionService();
    incomingController =
        StreamController<(Role, MessageEnvelope)>.broadcast();

    when(mockSession.incomingMessages)
        .thenAnswer((_) => incomingController.stream);
    when(mockSession.sendMessage(any, any)).thenAnswer((_) async {});
  });

  tearDown(() async {
    await incomingController.close();
  });

  // Builds a controller wired up with a real (minimal) voice + storage mock so
  // initialize() can be awaited without errors.
  Future<BibRecorderV2Controller> makeInitializedController() async {
    final mockStorage = MockIAssistantStorageService();
    final mockVoice = MockIVoiceRecognitionService();
    final mockHaptic = MockIHapticFeedback();

    when(mockVoice.bibNumbers)
        .thenAnswer((_) => StreamController<String?>.broadcast().stream);
    when(mockVoice.partialResults)
        .thenAnswer((_) => StreamController<String>.broadcast().stream);
    when(mockVoice.initialize())
        .thenAnswer((_) async => Failure<void>(const AppError(userMessage: '')));
    when(mockStorage.getRaces(any))
        .thenAnswer((_) async => const Success<List<RaceRecord>>([]));

    final controller = BibRecorderV2Controller(
      storage: mockStorage,
      voice: mockVoice,
      haptic: mockHaptic,
      session: mockSession,
    );
    await controller.initialize();
    return controller;
  }

  group('BibRecorderV2Controller', () {
    group('addBib', () {
      test('sends BibEntryMessage to verifier when session is set', () {
        final mockStorage = MockIAssistantStorageService();
        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
          session: mockSession,
        );

        controller.addBib(101);

        final captured =
            verify(mockSession.sendMessage(Role.verifier, captureAny)).captured;
        final envelope = captured.last as MessageEnvelope;
        expect(envelope.type, MessageType.bibEntry);
        final msg = envelope.decode() as BibEntryMessage;
        expect(msg.bib, 101);
        expect(msg.status, BibEntryStatus.resolved);
        expect(msg.finishPosition, 1);
      });

      test('assigns incrementing finish positions for consecutive bibs', () {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
          session: mockSession,
        );

        controller.addBib(101);
        controller.addBib(102);
        controller.addBib(103);

        final captured =
            verify(mockSession.sendMessage(Role.verifier, captureAny)).captured;
        expect(captured.length, 3);
        final positions = captured
            .map((e) =>
                ((e as MessageEnvelope).decode() as BibEntryMessage)
                    .finishPosition)
            .toList();
        expect(positions, [1, 2, 3]);
      });

      test('sends duplicate status when bib already recorded', () async {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
          session: mockSession,
        );

        controller.addBib(101);
        // Wait 2 ms so the second entry gets a distinct millisecond-based id,
        // ensuring the duplicate detection works correctly.
        await Future.delayed(const Duration(milliseconds: 2));
        controller.addBib(101); // duplicate

        final captured =
            verify(mockSession.sendMessage(Role.verifier, captureAny)).captured;
        final second =
            (captured.last as MessageEnvelope).decode() as BibEntryMessage;
        expect(second.status, BibEntryStatus.duplicate);
      });

      test('does not call sendMessage when no session is set', () {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );

        controller.addBib(101);

        verifyNever(mockSession.sendMessage(any, any));
      });

      test('includes runner context in message when bib matches roster', () async {
        final mockStorage = MockIAssistantStorageService();
        final race = RaceRecord(
          raceId: 1,
          date: DateTime(2026),
          name: 'Test Race',
          type: 'bibRecorder',
        );
        final runner = Runner(
          raceId: 1,
          bibNumber: '101',
          name: 'Alice',
          teamAbbreviation: 'NCC',
          teamColor: const Color(0xFF123456),
          createdAt: DateTime(2026),
        );
        when(mockStorage.getRaces(any))
            .thenAnswer((_) async => const Success<List<RaceRecord>>([]));
        when(mockStorage.getRunners(1))
            .thenAnswer((_) async => Success<List<Runner>>([runner]));
        when(mockStorage.getBibRecords(any))
            .thenAnswer((_) async => const Success<List<BibRecord>>([]));
        when(mockStorage.addBibRecord(any, any, any))
            .thenAnswer((_) async => const Success<void>(null));

        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
          session: mockSession,
        );
        controller.selectRace(race);
        await Future.microtask(() {});

        controller.addBib(101);

        final captured =
            verify(mockSession.sendMessage(Role.verifier, captureAny)).captured;
        final msg = (captured.last as MessageEnvelope).decode() as BibEntryMessage;
        expect(msg.runnerName, 'Alice');
        expect(msg.teamAbbreviation, 'NCC');
        expect(msg.teamColor, const Color(0xFF123456).toARGB32());
      });

      test('sends null runner context when bib is unknown', () {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
          session: mockSession,
        );

        // No runners loaded — bib is unknown.
        controller.addBib(999);

        final captured =
            verify(mockSession.sendMessage(Role.verifier, captureAny)).captured;
        final msg = (captured.last as MessageEnvelope).decode() as BibEntryMessage;
        expect(msg.runnerName, isNull);
        expect(msg.teamAbbreviation, isNull);
        expect(msg.teamColor, isNull);
      });
    });

    group('incoming FixerCorrectionMessage', () {
      test('malformed payload is dropped and stream listener remains alive', () async {
        final controller = await makeInitializedController();
        controller.addBib(101); // position 1

        // Malformed: missing required fields — fromJson will throw.
        incomingController.add((
          Role.fixer,
          MessageEnvelope(
            type: MessageType.fixerCorrection,
            version: messageSchemaVersion,
            payload: const {'bad_field': 'garbage'},
          ),
        ));
        await Future.microtask(() {});

        // Entry unchanged — malformed message was dropped.
        expect(controller.entries.first.correctedTo, isNull);

        // Subsequent valid message is still processed — listener still alive.
        incomingController.add((
          Role.fixer,
          MessageEnvelope.wrapFixerCorrection(const FixerCorrectionMessage(
            finishPosition: 1,
            originalBib: 101,
            correctedBib: 114,
            correctionType: CorrectionType.bibCorrected,
          )),
        ));
        await Future.microtask(() {});

        expect(controller.entries.first.correctedTo, 114);
      });
    });

    group('incoming FixerCorrectionMessage applies correction', () {
      test('sets correctedTo on matching entry and notifies listeners', () async {
        final controller = await makeInitializedController();
        controller.addBib(101); // position 1

        var notified = false;
        controller.addListener(() => notified = true);

        incomingController.add((
          Role.fixer,
          MessageEnvelope.wrapFixerCorrection(const FixerCorrectionMessage(
            finishPosition: 1,
            originalBib: 101,
            correctedBib: 114,
            correctionType: CorrectionType.bibCorrected,
          )),
        ));
        await Future.microtask(() {});

        expect(controller.entries.first.correctedTo, 114);
        expect(notified, isTrue);
      });

      test('is a no-op when finishPosition does not match any known entry', () async {
        final controller = await makeInitializedController();
        controller.addBib(101); // position 1

        incomingController.add((
          Role.fixer,
          MessageEnvelope.wrapFixerCorrection(const FixerCorrectionMessage(
            finishPosition: 99,
            originalBib: 101,
            correctedBib: 114,
            correctionType: CorrectionType.bibCorrected,
          )),
        ));
        await Future.microtask(() {});

        expect(controller.entries.first.correctedTo, isNull);
      });

      test('sets isNewRunner and leaves correctedTo null when correctionType is newRunner', () async {
        final controller = await makeInitializedController();
        controller.addBib(101); // position 1

        incomingController.add((
          Role.fixer,
          MessageEnvelope.wrapFixerCorrection(const FixerCorrectionMessage(
            finishPosition: 1,
            originalBib: 101,
            correctionType: CorrectionType.newRunner,
          )),
        ));
        await Future.microtask(() {});

        expect(controller.entries.first.correctedTo, isNull);
        expect(controller.entries.first.isNewRunner, isTrue);
      });
    });

    group('flagFor after correction', () {
      test('corrected entry is excluded from duplicate check', () async {
        final controller = await makeInitializedController();
        controller.addBib(101); // position 1 — first entry
        await Future.delayed(const Duration(milliseconds: 2));
        controller.addBib(101); // position 2 — duplicate

        // Apply correction to first entry (bib 101 → 114) via session stream.
        incomingController.add((
          Role.fixer,
          MessageEnvelope.wrapFixerCorrection(const FixerCorrectionMessage(
            finishPosition: 1,
            originalBib: 101,
            correctedBib: 114,
            correctionType: CorrectionType.bibCorrected,
          )),
        ));
        await Future.microtask(() {});

        // Second entry (bib 101) should no longer be a duplicate
        final secondEntry = controller.entries.firstWhere(
          (e) => e.correctedTo == null,
        );
        expect(controller.flagFor(secondEntry.bib, excludeId: secondEntry.id), isNull);
      });

      test('uncorrected duplicate is still flagged', () async {
        final controller = await makeInitializedController();
        controller.addBib(101);
        await Future.delayed(const Duration(milliseconds: 2));
        controller.addBib(101);

        final secondEntry = controller.entries.first;
        expect(
          controller.flagFor(secondEntry.bib, excludeId: secondEntry.id),
          'duplicate',
        );
      });
    });

    group('storage persistence (XCE-376)', () {
      RaceRecord makeRace() => RaceRecord(
            raceId: 1,
            date: DateTime(2026),
            name: 'Test Race',
            type: 'bibRecorderV2',
          );

      MockIAssistantStorageService makeStorage({
        List<BibRecord> bibRecords = const [],
      }) {
        final s = MockIAssistantStorageService();
        when(s.getRaces(any))
            .thenAnswer((_) async => const Success<List<RaceRecord>>([]));
        when(s.getRunners(any))
            .thenAnswer((_) async => const Success<List<Runner>>([]));
        when(s.getBibRecords(any))
            .thenAnswer((_) async => Success<List<BibRecord>>(bibRecords));
        when(s.addBibRecord(any, any, any))
            .thenAnswer((_) async => const Success<void>(null));
        when(s.updateBibRecordValue(any, any, any))
            .thenAnswer((_) async => const Success<void>(null));
        when(s.removeBibRecord(any, any))
            .thenAnswer((_) async => const Success<void>(null));
        when(s.deleteBibRecords(any))
            .thenAnswer((_) async => const Success<void>(null));
        when(s.deleteRace(any, any))
            .thenAnswer((_) async => const Success<void>(null));
        return s;
      }

      test('addBib calls addBibRecord with correct args', () async {
        final mockStorage = makeStorage();
        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.selectRace(makeRace());
        await Future.microtask(() {});

        controller.addBib(101);
        await Future.microtask(() {});

        verify(mockStorage.addBibRecord(1, any, '101')).called(1);
      });

      test('editEntry calls updateBibRecordValue with correct args', () async {
        final mockStorage = makeStorage();
        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.selectRace(makeRace());
        await Future.microtask(() {});
        controller.addBib(101);
        await Future.microtask(() {});
        final entryId = controller.entries.first.id;

        controller.editEntry(entryId, 202);
        await Future.microtask(() {});

        verify(mockStorage.updateBibRecordValue(1, entryId, '202')).called(1);
      });

      test('deleteEntry calls removeBibRecord with correct args', () async {
        final mockStorage = makeStorage();
        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.selectRace(makeRace());
        await Future.microtask(() {});
        controller.addBib(101);
        await Future.microtask(() {});
        final entryId = controller.entries.first.id;

        controller.deleteEntry(entryId);
        await Future.microtask(() {});

        verify(mockStorage.removeBibRecord(1, entryId)).called(1);
      });

      test('clearEntries calls deleteBibRecords', () async {
        final mockStorage = makeStorage();
        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.selectRace(makeRace());
        await Future.microtask(() {});

        controller.clearEntries();
        await Future.microtask(() {});

        verify(mockStorage.deleteBibRecords(1)).called(1);
      });

      test('deleteRace calls deleteRace on storage', () async {
        final mockStorage = makeStorage();
        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.selectRace(makeRace());
        await Future.microtask(() {});

        await controller.deleteRace();

        verify(mockStorage.deleteRace(1, any)).called(1);
      });

      test('selectRace loads existing bib records and restores entries', () async {
        final existingRecord = BibRecord(
          raceId: 1,
          bibId: 42,
          bibNumber: '105',
          createdAt: DateTime(2026),
        );
        final mockStorage = makeStorage(bibRecords: [existingRecord]);
        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );

        controller.selectRace(makeRace());
        await Future.microtask(() {});

        expect(controller.entries.length, 1);
        expect(controller.entries.first.id, 42);
        expect(controller.entries.first.bib, 105);
      });

      test('storage methods are not called when no race is selected', () async {
        final mockStorage = makeStorage();
        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );

        controller.addBib(101);
        await Future.microtask(() {});

        verifyNever(mockStorage.addBibRecord(any, any, any));
      });
    });

    group('stopRace unresolved handoff (XCE-379)', () {
      MockIAssistantStorageService makeStorage() {
        final s = MockIAssistantStorageService();
        when(s.getRaces(any))
            .thenAnswer((_) async => const Success<List<RaceRecord>>([]));
        when(s.getRunners(any))
            .thenAnswer((_) async => const Success<List<Runner>>([]));
        when(s.getBibRecords(any))
            .thenAnswer((_) async => const Success<List<BibRecord>>([]));
        when(s.addBibRecord(any, any, any))
            .thenAnswer((_) async => const Success<void>(null));
        when(s.saveChunk(any, any))
            .thenAnswer((_) async => const Success<void>(null));
        when(s.saveChunkConflict(any, any, any))
            .thenAnswer((_) async => const Success<void>(null));
        return s;
      }

      test('saveChunkConflict called for each unresolved entry on stopRace', () async {
        final mockStorage = makeStorage();
        final race = RaceRecord(
          raceId: 1,
          date: DateTime(2026),
          name: 'Test Race',
          type: 'bibRecorderV2',
        );
        // Load a roster so bibs can be flagged as unknown.
        final runner = Runner(
          raceId: 1,
          bibNumber: '200',
          createdAt: DateTime(2026),
        );
        when(mockStorage.getRunners(1))
            .thenAnswer((_) async => Success<List<Runner>>([runner]));

        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.selectRace(race);
        await Future.microtask(() {});

        // Add two unknown bibs (not in the roster).
        controller.addBib(101);
        await Future.delayed(const Duration(milliseconds: 2));
        controller.addBib(102);
        await Future.microtask(() {});

        controller.stopRace();
        // Pump enough for the async loop (2 entries × 2 awaits each).
        await Future.delayed(Duration.zero);

        verify(mockStorage.saveChunkConflict(1, any, any)).called(2);
      });

      test('resolved entries are not handed off as conflicts', () async {
        final mockStorage = makeStorage();
        final race = RaceRecord(
          raceId: 1,
          date: DateTime(2026),
          name: 'Test Race',
          type: 'bibRecorderV2',
        );
        final runner = Runner(
          raceId: 1,
          bibNumber: '200',
          createdAt: DateTime(2026),
        );
        when(mockStorage.getRunners(1))
            .thenAnswer((_) async => Success<List<Runner>>([runner]));

        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.attachSession(mockSession);
        controller.selectRace(race);
        await Future.microtask(() {});

        controller.addBib(101); // unknown — unresolved
        await Future.microtask(() {});

        // Apply correction via session stream so correctedTo is set.
        incomingController.add((
          Role.fixer,
          MessageEnvelope.wrapFixerCorrection(const FixerCorrectionMessage(
            finishPosition: 1,
            originalBib: 101,
            correctedBib: 200,
            correctionType: CorrectionType.bibCorrected,
          )),
        ));
        await Future.microtask(() {});

        controller.stopRace();
        await Future.delayed(Duration.zero);

        verifyNever(mockStorage.saveChunkConflict(any, any, any));
      });
    });

    group('addBib entry state', () {
      test('inserts entry at front of list', () {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.addBib(101);
        controller.addBib(202);
        expect(controller.entries.first.bib, 202);
        expect(controller.entries.length, 2);
      });

      test('lastAddedBib reflects the newly added bib', () {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.addBib(101);
        expect(controller.lastAddedBib, 101);
      });

      test('does not vibrate on duplicate — haptic is handled at recognition time', () async {
        final mockHaptic = MockIHapticFeedback();
        when(mockHaptic.vibrate()).thenAnswer((_) async {});
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: mockHaptic,
        );
        controller.addBib(101);
        // Wait 2 ms so the second entry gets a distinct id.
        await Future.delayed(const Duration(milliseconds: 2));
        controller.addBib(101); // duplicate
        verifyNever(mockHaptic.vibrate());
      });

      test('does not vibrate when bib is clean (no roster, no duplicates)', () {
        final mockHaptic = MockIHapticFeedback();
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: mockHaptic,
        );
        controller.addBib(101);
        verifyNever(mockHaptic.vibrate());
      });
    });

    group('reRecordLast', () {
      test('lastAddedBib returns null after reRecordLast', () {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.addBib(101);
        expect(controller.lastAddedBib, 101);
        controller.reRecordLast();
        expect(controller.lastAddedBib, isNull);
      });

      test('lastAddedBib resumes after next addBib', () {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.addBib(101);
        controller.reRecordLast();
        controller.addBib(202);
        expect(controller.lastAddedBib, 202);
      });

      test('is a no-op when entries is empty', () {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.reRecordLast();
        expect(controller.lastAddedBib, isNull);
        expect(controller.entries, isEmpty);
      });
    });

    group('deleteEntry / editEntry / clearEntries', () {
      test('deleteEntry removes entry from list', () {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.addBib(101);
        final id = controller.entries.first.id;
        controller.deleteEntry(id);
        expect(controller.entries, isEmpty);
      });

      test('editEntry updates bib in list', () {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.addBib(101);
        final id = controller.entries.first.id;
        controller.editEntry(id, 202);
        expect(controller.entries.first.bib, 202);
      });

      test('editEntry is a no-op for unknown id', () {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.addBib(101);
        controller.editEntry(999, 202);
        expect(controller.entries.first.bib, 101);
      });

      test('clearEntries empties the list', () {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.addBib(101);
        controller.addBib(202);
        controller.clearEntries();
        expect(controller.entries, isEmpty);
      });

      test('restoreEntry re-inserts entry at correct index', () {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.addBib(101);
        final entry = controller.entries.first;
        controller.deleteEntry(entry.id);
        expect(controller.entries, isEmpty);

        controller.restoreEntry(entry, 0);
        expect(controller.entries.length, 1);
        expect(controller.entries.first.bib, 101);
      });

      test('restoreEntry clamps index when out of bounds', () {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.addBib(101);
        final entry = controller.entries.first;
        controller.deleteEntry(entry.id);

        controller.restoreEntry(entry, 99);
        expect(controller.entries.length, 1);
        expect(controller.entries.last.bib, 101);
      });
    });

    group('flagFor', () {
      test('returns null when roster is empty (no unknown flag without roster)', () {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        expect(controller.flagFor(999), isNull);
      });

      test('returns null when bib is in roster', () async {
        final mockStorage = MockIAssistantStorageService();
        when(mockStorage.getRaces(any))
            .thenAnswer((_) async => const Success<List<RaceRecord>>([]));
        when(mockStorage.getRunners(1)).thenAnswer(
          (_) async => Success<List<Runner>>([
            Runner(raceId: 1, bibNumber: '101', createdAt: DateTime(2026)),
          ]),
        );
        when(mockStorage.getBibRecords(any))
            .thenAnswer((_) async => const Success<List<BibRecord>>([]));
        final race = RaceRecord(
          raceId: 1,
          date: DateTime(2026),
          name: 'Test Race',
          type: 'bibRecorderV2',
        );
        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.selectRace(race);
        await Future.microtask(() {});
        expect(controller.flagFor(101), isNull);
      });

      test('returns unknown when roster loaded and bib absent', () async {
        final mockStorage = MockIAssistantStorageService();
        when(mockStorage.getRaces(any))
            .thenAnswer((_) async => const Success<List<RaceRecord>>([]));
        when(mockStorage.getRunners(1)).thenAnswer(
          (_) async => Success<List<Runner>>([
            Runner(raceId: 1, bibNumber: '200', createdAt: DateTime(2026)),
          ]),
        );
        when(mockStorage.getBibRecords(any))
            .thenAnswer((_) async => const Success<List<BibRecord>>([]));
        final race = RaceRecord(
          raceId: 1,
          date: DateTime(2026),
          name: 'Test Race',
          type: 'bibRecorderV2',
        );
        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.selectRace(race);
        await Future.microtask(() {});
        expect(controller.flagFor(999), 'unknown');
      });
    });

    group('voice state', () {
      late StreamController<String?> bibStreamCtrl;
      late StreamController<String> transcriptStreamCtrl;

      setUp(() {
        bibStreamCtrl = StreamController<String?>.broadcast();
        transcriptStreamCtrl = StreamController<String>.broadcast();
      });

      tearDown(() async {
        await bibStreamCtrl.close();
        await transcriptStreamCtrl.close();
      });

      Future<BibRecorderV2Controller> makeVoiceController({
        bool voiceSuccess = true,
      }) async {
        final mockStorage = MockIAssistantStorageService();
        final mockVoice = MockIVoiceRecognitionService();
        when(mockVoice.bibNumbers)
            .thenAnswer((_) => bibStreamCtrl.stream);
        when(mockVoice.partialResults)
            .thenAnswer((_) => transcriptStreamCtrl.stream);
        when(mockVoice.initialize()).thenAnswer((_) async => voiceSuccess
            ? const Success<void>(null)
            : Failure<void>(const AppError(userMessage: 'voice failed')));
        when(mockVoice.start()).thenAnswer((_) async {});
        when(mockVoice.stop()).thenAnswer((_) async {});
        when(mockStorage.getRaces(any))
            .thenAnswer((_) async => const Success<List<RaceRecord>>([]));
        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: mockVoice,
          haptic: MockIHapticFeedback(),
        );
        await controller.initialize();
        return controller;
      }

      test('isListening becomes true on startListening', () async {
        final controller = await makeVoiceController();
        expect(controller.isListening, isFalse);
        await controller.startListening();
        expect(controller.isListening, isTrue);
      });

      test('isListening becomes false on stopListening', () async {
        final controller = await makeVoiceController();
        await controller.startListening();
        await controller.stopListening();
        expect(controller.isListening, isFalse);
      });

      test('isProcessing is set after stopListening', () async {
        final controller = await makeVoiceController();
        await controller.startListening();
        await controller.stopListening();
        expect(controller.isProcessing, isTrue);
      });

      test('isProcessing is cleared when bib stream emits', () async {
        final controller = await makeVoiceController();
        await controller.startListening();
        await controller.stopListening();
        expect(controller.isProcessing, isTrue);
        bibStreamCtrl.add(null);
        await Future.microtask(() {});
        expect(controller.isProcessing, isFalse);
      });

      test('voiceError is set when initialize returns Failure', () async {
        final controller = await makeVoiceController(voiceSuccess: false);
        expect(controller.voiceError, isNotNull);
        expect(controller.voiceError!.userMessage, 'voice failed');
      });

      test('voiceReady is true when initialize succeeds', () async {
        final controller = await makeVoiceController();
        expect(controller.voiceReady, isTrue);
      });

      test('vibrates when voice recognition returns null', () async {
        final mockHaptic = MockIHapticFeedback();
        when(mockHaptic.vibrate()).thenAnswer((_) async {});
        final mockStorage = MockIAssistantStorageService();
        final mockVoice = MockIVoiceRecognitionService();
        when(mockVoice.bibNumbers)
            .thenAnswer((_) => bibStreamCtrl.stream);
        when(mockVoice.partialResults)
            .thenAnswer((_) => transcriptStreamCtrl.stream);
        when(mockVoice.initialize())
            .thenAnswer((_) async => const Success<void>(null));
        when(mockVoice.start()).thenAnswer((_) async {});
        when(mockVoice.stop()).thenAnswer((_) async {});
        when(mockStorage.getRaces(any))
            .thenAnswer((_) async => const Success<List<RaceRecord>>([]));
        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: mockVoice,
          haptic: mockHaptic,
        );
        await controller.initialize();
        await controller.startListening();
        await controller.stopListening();
        bibStreamCtrl.add(null);
        await Future.microtask(() {});
        verify(mockHaptic.vibrate()).called(1);
      });
    });

    group('leaveRace', () {
      test('clears entries, transcript, and listening state', () {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.addBib(101);
        controller.addBib(202);
        controller.leaveRace();
        expect(controller.entries, isEmpty);
        expect(controller.isListening, isFalse);
        expect(controller.isProcessing, isFalse);
        expect(controller.transcript, '');
        expect(controller.selectedRace, isNull);
        expect(controller.raceStarted, isFalse);
      });

      test('lastAddedBib is null after leaveRace', () {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.addBib(101);
        controller.leaveRace();
        expect(controller.lastAddedBib, isNull);
      });
    });

    group('incoming FixerCorrectionMessage', () {
      test('applies correctedTo on matching entry', () async {
        final controller = await makeInitializedController();

        controller.addBib(101); // position 1
        expect(controller.entries.first.correctedTo, isNull);

        incomingController.add((
          Role.fixer,
          MessageEnvelope.wrapFixerCorrection(
            const FixerCorrectionMessage(
              finishPosition: 1,
              originalBib: 101,
              correctedBib: 114,
              correctionType: CorrectionType.bibCorrected,
            ),
          ),
        ));

        await Future.microtask(() {});

        expect(controller.entries.first.correctedTo, 114);
      });

      test('ignores correction for unknown finish position', () async {
        final controller = await makeInitializedController();

        controller.addBib(101); // position 1

        incomingController.add((
          Role.fixer,
          MessageEnvelope.wrapFixerCorrection(
            const FixerCorrectionMessage(
              finishPosition: 99,
              originalBib: 101,
              correctedBib: 114,
              correctionType: CorrectionType.bibCorrected,
            ),
          ),
        ));

        await Future.microtask(() {});

        expect(controller.entries.first.correctedTo, isNull);
      });

      test('ignores non-correction message types', () async {
        final controller = await makeInitializedController();

        controller.addBib(101);

        incomingController.add((
          Role.bibRecorderV2,
          MessageEnvelope.wrapBibEntry(
            BibEntryMessage(
              finishPosition: 1,
              bib: 101,
              status: BibEntryStatus.resolved,
              timestamp: DateTime.now(),
            ),
          ),
        ));

        await Future.microtask(() {});

        expect(controller.entries.first.correctedTo, isNull);
      });
    });

    group('processLoadedRaceData', () {
      final testRace = RaceRecord(
        raceId: 1,
        date: DateTime(2026),
        name: 'Test Race',
        type: 'bibRecorderV2',
      );
      const validRunnerJson = '{"teams":["EAG"],"r":[["42","Alice",0,"10"]]}';

      MockIAssistantStorageService makeStorage() {
        final s = MockIAssistantStorageService();
        when(s.getRaces(any))
            .thenAnswer((_) async => const Success<List<RaceRecord>>([]));
        when(s.saveNewRace(any))
            .thenAnswer((_) async => const Success<void>(null));
        when(s.saveRunners(any, any))
            .thenAnswer((_) async => const Success<void>(null));
        return s;
      }

      test('returns Failure when data cannot be parsed', () async {
        final mockStorage = makeStorage();
        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );

        final result = await controller.processLoadedRaceData('not valid json');

        expect(result, isA<Failure<void>>());
      });

      test('returns Failure when runner section is invalid', () async {
        final mockStorage = makeStorage();
        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        final data = '${testRace.encode()}---invalid-runner-data';

        final result = await controller.processLoadedRaceData(data);

        expect(result, isA<Failure<void>>());
      });

      test('returns Failure when saveNewRace fails', () async {
        final mockStorage = makeStorage();
        when(mockStorage.saveNewRace(any)).thenAnswer(
          (_) async => Failure<void>(const AppError(userMessage: 'Save failed')),
        );
        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );

        final result = await controller.processLoadedRaceData(testRace.encode());

        expect(result, isA<Failure<void>>());
        expect((result as Failure).error.userMessage, 'Save failed');
      });

      test('returns Success and reloads race list on valid data without runners', () async {
        final mockStorage = makeStorage();
        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );

        final result = await controller.processLoadedRaceData(testRace.encode());

        expect(result, isA<Success<void>>());
        verify(mockStorage.saveNewRace(any)).called(1);
        verifyNever(mockStorage.saveRunners(any, any));
        // getRaces called once for initialize() reload after save
        verify(mockStorage.getRaces(any)).called(1);
      });

      test('returns Success and calls saveRunners on valid data with runners', () async {
        final mockStorage = makeStorage();
        final controller = BibRecorderV2Controller(
          storage: mockStorage,
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        final data = '${testRace.encode()}---$validRunnerJson';

        final result = await controller.processLoadedRaceData(data);

        expect(result, isA<Success<void>>());
        verify(mockStorage.saveNewRace(any)).called(1);
        verify(mockStorage.saveRunners(any, any)).called(1);
      });
    });

    group('attachSession', () {
      test('subscribes to incoming messages after construction without session',
          () async {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );

        controller.attachSession(mockSession);

        final msg = FixerCorrectionMessage(
          finishPosition: 1,
          originalBib: 99,
          correctedBib: 42,
          correctionType: CorrectionType.bibCorrected,
        );
        // addBib first so position 1 is mapped
        controller.addBib(99);
        incomingController
            .add((Role.fixer, MessageEnvelope.wrapFixerCorrection(msg)));

        await Future.microtask(() {});

        expect(controller.entries.first.correctedTo, 42);
      });

      test('sends bib messages via newly attached session', () {
        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );

        controller.attachSession(mockSession);
        controller.addBib(55);

        final captured =
            verify(mockSession.sendMessage(Role.verifier, captureAny)).captured;
        expect(captured.length, 1);
        final envelope = captured.first as MessageEnvelope;
        expect(envelope.type, MessageType.bibEntry);
      });

      test('replaces prior session subscription without leaking', () async {
        final secondController =
            StreamController<(Role, MessageEnvelope)>.broadcast();
        final secondSession = MockP2PSessionService();
        when(secondSession.incomingMessages)
            .thenAnswer((_) => secondController.stream);
        when(secondSession.sendMessage(any, any)).thenAnswer((_) async {});

        final controller = BibRecorderV2Controller(
          storage: MockIAssistantStorageService(),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
          session: mockSession,
        );

        // Replace with second session.
        controller.attachSession(secondSession);

        // Message on old stream — should be ignored.
        controller.addBib(10);
        incomingController.add((
          Role.fixer,
          MessageEnvelope.wrapFixerCorrection(FixerCorrectionMessage(
            finishPosition: 1,
            originalBib: 10,
            correctedBib: 99,
            correctionType: CorrectionType.bibCorrected,
          )),
        ));

        await Future.microtask(() {});

        // correctedTo should still be null — old stream was cancelled.
        expect(controller.entries.first.correctedTo, isNull);

        await secondController.close();
      });
    });

    group('_loadBibRecords populates position map (XCE-523)', () {
      MockIAssistantStorageService makeStorage(List<BibRecord> records) {
        final s = MockIAssistantStorageService();
        when(s.getRaces(any))
            .thenAnswer((_) async => const Success<List<RaceRecord>>([]));
        when(s.getRunners(any))
            .thenAnswer((_) async => const Success<List<Runner>>([]));
        when(s.getBibRecords(any))
            .thenAnswer((_) async => Success<List<BibRecord>>(records));
        when(s.addBibRecord(any, any, any))
            .thenAnswer((_) async => const Success(null));
        return s;
      }

      RaceRecord makeRace() => RaceRecord(
            raceId: 1,
            date: DateTime(2026),
            name: 'Test Race',
            type: 'bibRecorderV2',
          );

      test('Fixer correction for pre-loaded entry is applied correctly', () async {
        final records = [
          BibRecord(raceId: 1, bibId: 1001, bibNumber: '101', createdAt: DateTime(2026)),
          BibRecord(raceId: 1, bibId: 1002, bibNumber: '102', createdAt: DateTime(2026)),
        ];
        final controller = BibRecorderV2Controller(
          storage: makeStorage(records),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
        );
        controller.attachSession(mockSession);
        controller.selectRace(makeRace());
        await Future.microtask(() {});

        // Position 1 corresponds to the first loaded entry (bibId 1001).
        incomingController.add((
          Role.fixer,
          MessageEnvelope.wrapFixerCorrection(const FixerCorrectionMessage(
            finishPosition: 1,
            originalBib: 101,
            correctedBib: 114,
            correctionType: CorrectionType.bibCorrected,
          )),
        ));
        await Future.microtask(() {});

        final entry = controller.entries.firstWhere((e) => e.id == 1001);
        expect(entry.correctedTo, 114);
      });

      test('new bibs after resume continue positions from loaded count', () async {
        final records = [
          BibRecord(raceId: 1, bibId: 2001, bibNumber: '50', createdAt: DateTime(2026)),
          BibRecord(raceId: 1, bibId: 2002, bibNumber: '51', createdAt: DateTime(2026)),
        ];
        final controller = BibRecorderV2Controller(
          storage: makeStorage(records),
          voice: MockIVoiceRecognitionService(),
          haptic: MockIHapticFeedback(),
          session: mockSession,
        );
        controller.selectRace(makeRace());
        await Future.microtask(() {});

        // 2 loaded entries → _nextPosition == 2. New bib gets position 3.
        controller.addBib(99);

        final captured =
            verify(mockSession.sendMessage(Role.verifier, captureAny)).captured;
        final msg = (captured.last as MessageEnvelope).decode() as BibEntryMessage;
        expect(msg.finishPosition, 3);
      });
    });

    group('incoming FixerCorrectionMessage — newRunner handling (XCE-525)', () {
      test('sets isNewRunner on entry when correctedBib is null and type is newRunner', () async {
        final controller = await makeInitializedController();
        controller.addBib(177); // position 1

        incomingController.add((
          Role.fixer,
          MessageEnvelope.wrapFixerCorrection(
            const FixerCorrectionMessage(
              finishPosition: 1,
              originalBib: 177,
              correctedBib: null,
              correctionType: CorrectionType.newRunner,
            ),
          ),
        ));
        await Future.microtask(() {});

        expect(controller.entries.first.isNewRunner, isTrue);
        expect(controller.entries.first.correctedTo, isNull);
      });

      test('flagFor returns null for isNewRunner entry (no longer flagged)', () async {
        final controller = await makeInitializedController();
        controller.addBib(177); // position 1

        incomingController.add((
          Role.fixer,
          MessageEnvelope.wrapFixerCorrection(
            const FixerCorrectionMessage(
              finishPosition: 1,
              originalBib: 177,
              correctedBib: null,
              correctionType: CorrectionType.newRunner,
            ),
          ),
        ));
        await Future.microtask(() {});

        final entry = controller.entries.first;
        expect(controller.flagFor(entry.bib, excludeId: entry.id), isNull);
      });
    });
  });
}
