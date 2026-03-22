import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/i_voice_recognition_service.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/controller/bib_recorder_v2_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/bib_correction_message.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/haptic_feedback_service.dart';
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
        .thenAnswer((_) => StreamController<int?>.broadcast().stream);
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

    group('applyCorrection', () {
      test('sets correctedTo on matching entry and notifies listeners', () async {
        final controller = await makeInitializedController();
        controller.addBib(101); // position 1

        var notified = false;
        controller.addListener(() => notified = true);

        controller.applyCorrection(const BibCorrectionMessage(
          entryId: 1,
          originalBib: 101,
          correctedBib: 114,
        ));

        expect(controller.entries.first.correctedTo, 114);
        expect(notified, isTrue);
      });

      test('is a no-op when entryId does not match any finish position', () async {
        final controller = await makeInitializedController();
        controller.addBib(101); // position 1

        controller.applyCorrection(const BibCorrectionMessage(
          entryId: 99,
          originalBib: 101,
          correctedBib: 114,
        ));

        expect(controller.entries.first.correctedTo, isNull);
      });

      test('sets correctedTo to null when correctedBib is null', () async {
        final controller = await makeInitializedController();
        controller.addBib(101); // position 1

        controller.applyCorrection(const BibCorrectionMessage(
          entryId: 1,
          originalBib: 101,
          isNewRunner: true,
        ));

        // correctedBib is null → correctedTo should not be changed from null
        expect(controller.entries.first.correctedTo, isNull);
      });
    });

    group('flagFor after correction', () {
      test('corrected entry is excluded from duplicate check', () async {
        final controller = await makeInitializedController();
        controller.addBib(101); // position 1 — first entry
        await Future.delayed(const Duration(milliseconds: 2));
        controller.addBib(101); // position 2 — duplicate

        // Apply correction to first entry (bib 101 → 114)
        controller.applyCorrection(const BibCorrectionMessage(
          entryId: 1,
          originalBib: 101,
          correctedBib: 114,
        ));

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
  });
}
