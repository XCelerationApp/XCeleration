import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/verifier_entry.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
import 'package:xceleration/assistant/finish_line_roles/verifier/controller/verifier_controller.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/haptic_feedback_service.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

import 'verifier_controller_test.mocks.dart';

@GenerateMocks([P2PSessionService, IAssistantStorageService, IHapticFeedback])
void main() {
  late MockP2PSessionService mockSession;
  late MockIAssistantStorageService mockStorage;
  late MockIHapticFeedback mockHaptic;
  late StreamController<(Role, MessageEnvelope)> incomingController;

  final testRace = RaceRecord(
    raceId: 1,
    date: DateTime(2026),
    name: 'Test Race',
    type: 'verifier',
  );
  const validRunnerJson = '{"teams":["EAG"],"r":[["42","Alice",0,"10"]]}';

  setUp(() {
    mockSession = MockP2PSessionService();
    mockStorage = MockIAssistantStorageService();
    mockHaptic = MockIHapticFeedback();
    incomingController =
        StreamController<(Role, MessageEnvelope)>.broadcast();

    when(mockSession.incomingMessages)
        .thenAnswer((_) => incomingController.stream);
    when(mockHaptic.vibrate()).thenAnswer((_) async {});
    when(mockHaptic.lightImpact()).thenAnswer((_) async {});
    when(mockSession.sendMessage(any, any)).thenAnswer((_) async {});
    when(mockStorage.getRaces(any))
        .thenAnswer((_) async => const Success<List<RaceRecord>>([]));
    when(mockStorage.saveNewRace(any))
        .thenAnswer((_) async => const Success<void>(null));
    when(mockStorage.saveRunners(any, any))
        .thenAnswer((_) async => const Success<void>(null));
    when(mockStorage.getVerifierEntries(any))
        .thenAnswer((_) async => const Success<List<VerifierEntry>>([]));
    when(mockStorage.saveVerifierEntry(any, any))
        .thenAnswer((_) async => const Success<void>(null));
    when(mockStorage.updateVerifierEntryStatus(any, any, any))
        .thenAnswer((_) async => const Success<void>(null));
  });

  setUpAll(() {
    provideDummy<Result<void>>(Failure<void>(const AppError(userMessage: '')));
    provideDummy<Result<List<RaceRecord>>>(const Success([]));
    provideDummy<Result<List<Runner>>>(const Success([]));
    provideDummy<Result<List<VerifierEntry>>>(const Success([]));
  });

  tearDown(() async {
    await incomingController.close();
  });

  group('VerifierController', () {
    group('initialize', () {
      test('subscribes to incoming messages when session is set', () async {
        final controller = VerifierController(session: mockSession, haptic: mockHaptic);
        controller.initialize();

        final msg = BibEntryMessage(
          finishPosition: 1,
          bib: 101,
          status: BibEntryStatus.resolved,
          timestamp: DateTime.now(),
        );
        incomingController.add((Role.bibRecorderV2, MessageEnvelope.wrapBibEntry(msg)));

        await Future.microtask(() {});

        expect(controller.entries.length, 1);
        expect(controller.entries.first.bib, 101);
      });
    });

    group('incoming BibEntryMessage', () {
      test('adds resolved entry with no flag', () async {
        final controller = VerifierController(session: mockSession, haptic: mockHaptic);
        controller.initialize();

        incomingController.add((
          Role.bibRecorderV2,
          MessageEnvelope.wrapBibEntry(BibEntryMessage(
            finishPosition: 3,
            bib: 205,
            status: BibEntryStatus.resolved,
            timestamp: DateTime.now(),
          )),
        ));

        await Future.microtask(() {});

        expect(controller.entries.length, 1);
        final entry = controller.entries.first;
        expect(entry.bib, 205);
        expect(entry.position, 3);
        expect(entry.flag, BibFlag.none);
        expect(entry.status, VerificationStatus.pending);
      });

      test('adds entry with duplicate flag', () async {
        final controller = VerifierController(session: mockSession, haptic: mockHaptic);
        controller.initialize();

        incomingController.add((
          Role.bibRecorderV2,
          MessageEnvelope.wrapBibEntry(BibEntryMessage(
            finishPosition: 2,
            bib: 107,
            status: BibEntryStatus.duplicate,
            timestamp: DateTime.now(),
          )),
        ));

        await Future.microtask(() {});

        expect(controller.entries.first.flag, BibFlag.duplicate);
      });

      test('adds entry with unknown flag', () async {
        final controller = VerifierController(session: mockSession, haptic: mockHaptic);
        controller.initialize();

        incomingController.add((
          Role.bibRecorderV2,
          MessageEnvelope.wrapBibEntry(BibEntryMessage(
            finishPosition: 4,
            bib: 999,
            status: BibEntryStatus.unknown,
            timestamp: DateTime.now(),
          )),
        ));

        await Future.microtask(() {});

        expect(controller.entries.first.flag, BibFlag.unknown);
      });

      test('populates runner context from message when present', () async {
        final controller = VerifierController(session: mockSession, haptic: mockHaptic);
        controller.initialize();

        incomingController.add((
          Role.bibRecorderV2,
          MessageEnvelope.wrapBibEntry(BibEntryMessage(
            finishPosition: 5,
            bib: 42,
            status: BibEntryStatus.resolved,
            timestamp: DateTime.now(),
            runnerName: 'Alice',
            teamAbbreviation: 'NCC',
            teamColor: const Color(0xFF123456).toARGB32(),
          )),
        ));

        await Future.microtask(() {});

        final entry = controller.entries.first;
        expect(entry.runnerName, 'Alice');
        expect(entry.teamAbbreviation, 'NCC');
        expect(entry.teamColor, const Color(0xFF123456));
      });

      test('leaves runner context null for unknown bib', () async {
        final controller = VerifierController(session: mockSession, haptic: mockHaptic);
        controller.initialize();

        incomingController.add((
          Role.bibRecorderV2,
          MessageEnvelope.wrapBibEntry(BibEntryMessage(
            finishPosition: 6,
            bib: 999,
            status: BibEntryStatus.unknown,
            timestamp: DateTime.now(),
          )),
        ));

        await Future.microtask(() {});

        final entry = controller.entries.first;
        expect(entry.runnerName, isNull);
        expect(entry.teamAbbreviation, isNull);
        expect(entry.teamColor, isNull);
      });

      test('ignores non-bibEntry message types', () async {
        final controller = VerifierController(session: mockSession, haptic: mockHaptic);
        controller.initialize();

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

        expect(controller.entries, isEmpty);
      });

      test('malformed bibEntry payload is dropped and stream listener remains alive', () async {
        final controller = VerifierController(session: mockSession, haptic: mockHaptic);
        controller.initialize();

        // Malformed: missing required fields — fromJson will throw.
        incomingController.add((
          Role.bibRecorderV2,
          MessageEnvelope(
            type: MessageType.bibEntry,
            version: messageSchemaVersion,
            payload: const {'bad_field': 'garbage'},
          ),
        ));
        await Future.microtask(() {});

        expect(controller.entries, isEmpty);

        // Subsequent valid message is still processed — listener still alive.
        incomingController.add((
          Role.bibRecorderV2,
          MessageEnvelope.wrapBibEntry(BibEntryMessage(
            finishPosition: 1,
            bib: 101,
            status: BibEntryStatus.resolved,
            timestamp: DateTime.now(),
          )),
        ));
        await Future.microtask(() {});

        expect(controller.entries.length, 1);
        expect(controller.entries.first.bib, 101);
      });
    });

    group('flag', () {
      test('sends VerifierFlagMessage to fixer after 3-second undo window', () {
        fakeAsync((fake) {
          final controller = VerifierController(session: mockSession, haptic: mockHaptic);
          controller.initialize();

          incomingController.add((
            Role.bibRecorderV2,
            MessageEnvelope.wrapBibEntry(BibEntryMessage(
              finishPosition: 1,
              bib: 101,
              status: BibEntryStatus.resolved,
              timestamp: DateTime.now(),
            )),
          ));
          fake.flushMicrotasks();

          controller.flag(1);

          // Message not sent yet — undo window still open.
          verifyNever(mockSession.sendMessage(any, any));

          fake.elapse(const Duration(seconds: 3));

          final captured =
              verify(mockSession.sendMessage(Role.fixer, captureAny)).captured;
          final envelope = captured.last as MessageEnvelope;
          expect(envelope.type, MessageType.verifierFlag);
          final msg = envelope.decode() as VerifierFlagMessage;
          expect(msg.entry.bib, 101);
          expect(msg.entry.finishPosition, 1);
          expect(msg.reason, FlagReason.wrongName);
        });
      });

      test('sends FlagReason.unknown for unknown-flagged entry after undo window', () {
        fakeAsync((fake) {
          final controller = VerifierController(session: mockSession, haptic: mockHaptic);
          controller.initialize();

          incomingController.add((
            Role.bibRecorderV2,
            MessageEnvelope.wrapBibEntry(BibEntryMessage(
              finishPosition: 2,
              bib: 999,
              status: BibEntryStatus.unknown,
              timestamp: DateTime.now(),
            )),
          ));
          fake.flushMicrotasks();

          controller.flag(2);
          fake.elapse(const Duration(seconds: 3));

          final captured =
              verify(mockSession.sendMessage(Role.fixer, captureAny)).captured;
          final msg =
              (captured.last as MessageEnvelope).decode() as VerifierFlagMessage;
          expect(msg.reason, FlagReason.unknown);
        });
      });

      test('sends FlagReason.duplicate for duplicate-flagged entry after undo window', () {
        fakeAsync((fake) {
          final controller = VerifierController(session: mockSession, haptic: mockHaptic);
          controller.initialize();

          incomingController.add((
            Role.bibRecorderV2,
            MessageEnvelope.wrapBibEntry(BibEntryMessage(
              finishPosition: 3,
              bib: 107,
              status: BibEntryStatus.duplicate,
              timestamp: DateTime.now(),
            )),
          ));
          fake.flushMicrotasks();

          controller.flag(3);
          fake.elapse(const Duration(seconds: 3));

          final captured =
              verify(mockSession.sendMessage(Role.fixer, captureAny)).captured;
          final msg =
              (captured.last as MessageEnvelope).decode() as VerifierFlagMessage;
          expect(msg.reason, FlagReason.duplicate);
        });
      });

      test('does not send message when flag is undone within 3 seconds', () {
        fakeAsync((fake) {
          final controller = VerifierController(session: mockSession, haptic: mockHaptic);
          controller.initialize();

          incomingController.add((
            Role.bibRecorderV2,
            MessageEnvelope.wrapBibEntry(BibEntryMessage(
              finishPosition: 1,
              bib: 101,
              status: BibEntryStatus.resolved,
              timestamp: DateTime.now(),
            )),
          ));
          fake.flushMicrotasks();

          controller.flag(1);
          controller.undo(1); // cancel within undo window

          fake.elapse(const Duration(seconds: 5));

          verifyNever(mockSession.sendMessage(any, any));
        });
      });

      test('does not send message when no session is set', () {
        fakeAsync((fake) {
          final controller = VerifierController(haptic: mockHaptic);
          controller.joinRace(raceId: 1);

          controller.flag(1); // no session — flag is a no-op for P2P

          fake.elapse(const Duration(seconds: 3));

          verifyNever(mockSession.sendMessage(any, any));
        });
      });
    });

    group('verify / flag / skip immediate status', () {
      BibEntryMessage makeMsg(int position, int bib,
          {BibEntryStatus status = BibEntryStatus.resolved}) =>
          BibEntryMessage(
            finishPosition: position,
            bib: bib,
            status: status,
            timestamp: DateTime.now(),
          );

      test('verify updates entry status to verified immediately', () async {
        final controller = VerifierController(session: mockSession, haptic: mockHaptic);
        controller.initialize();
        incomingController.add((
          Role.bibRecorderV2,
          MessageEnvelope.wrapBibEntry(makeMsg(1, 101)),
        ));
        await Future.microtask(() {});

        controller.verify(1);

        expect(controller.entries.first.status, VerificationStatus.verified);
      });

      test('flag updates entry status to flagged immediately', () async {
        final controller = VerifierController(session: mockSession, haptic: mockHaptic);
        controller.initialize();
        incomingController.add((
          Role.bibRecorderV2,
          MessageEnvelope.wrapBibEntry(makeMsg(2, 202)),
        ));
        await Future.microtask(() {});

        controller.flag(2);

        expect(controller.entries.first.status, VerificationStatus.flagged);
      });

      test('skip updates entry status to skipped immediately', () async {
        final controller = VerifierController(session: mockSession, haptic: mockHaptic);
        controller.initialize();
        incomingController.add((
          Role.bibRecorderV2,
          MessageEnvelope.wrapBibEntry(makeMsg(3, 303)),
        ));
        await Future.microtask(() {});

        controller.skip(3);

        expect(controller.entries.first.status, VerificationStatus.skipped);
      });

      test('acted entry remains in entries within the 3-second window', () async {
        final controller = VerifierController(session: mockSession, haptic: mockHaptic);
        controller.initialize();
        incomingController.add((
          Role.bibRecorderV2,
          MessageEnvelope.wrapBibEntry(makeMsg(1, 101)),
        ));
        await Future.microtask(() {});

        controller.verify(1);

        expect(controller.entries, isNotEmpty);
        expect(controller.entries.first.status, VerificationStatus.verified);
      });
    });

    group('undo timer', () {
      BibEntryMessage makeMsg(int position, int bib) => BibEntryMessage(
            finishPosition: position,
            bib: bib,
            status: BibEntryStatus.resolved,
            timestamp: DateTime.now(),
          );

      test('entry moves to history after 3 seconds', () {
        fakeAsync((fake) {
          final controller = VerifierController(session: mockSession, haptic: mockHaptic);
          controller.initialize();
          incomingController.add((
            Role.bibRecorderV2,
            MessageEnvelope.wrapBibEntry(makeMsg(1, 101)),
          ));
          fake.flushMicrotasks();

          controller.verify(1);
          expect(controller.entries, isNotEmpty);

          fake.elapse(const Duration(seconds: 3));

          expect(controller.entries, isEmpty);
          expect(controller.confirmed, 1);
        });
      });

      test('confirmed count is 0 before timer fires', () {
        fakeAsync((fake) {
          final controller = VerifierController(session: mockSession, haptic: mockHaptic);
          controller.initialize();
          incomingController.add((
            Role.bibRecorderV2,
            MessageEnvelope.wrapBibEntry(makeMsg(1, 101)),
          ));
          fake.flushMicrotasks();

          controller.verify(1);

          // Not yet committed — timer hasn't fired.
          expect(controller.confirmed, 0);
        });
      });

      test('wrong count increments after flagged entry commits', () {
        fakeAsync((fake) {
          final controller = VerifierController(session: mockSession, haptic: mockHaptic);
          controller.initialize();
          incomingController.add((
            Role.bibRecorderV2,
            MessageEnvelope.wrapBibEntry(makeMsg(2, 202)),
          ));
          fake.flushMicrotasks();

          controller.flag(2);
          fake.elapse(const Duration(seconds: 3));

          expect(controller.wrong, 1);
          expect(controller.confirmed, 0);
        });
      });

      test('skipped count increments after skipped entry commits', () {
        fakeAsync((fake) {
          final controller = VerifierController(session: mockSession, haptic: mockHaptic);
          controller.initialize();
          incomingController.add((
            Role.bibRecorderV2,
            MessageEnvelope.wrapBibEntry(makeMsg(3, 303)),
          ));
          fake.flushMicrotasks();

          controller.skip(3);
          fake.elapse(const Duration(seconds: 3));

          expect(controller.skipped, 1);
        });
      });

      test('pending count excludes acted-but-not-committed entries', () {
        fakeAsync((fake) {
          final controller = VerifierController(session: mockSession, haptic: mockHaptic);
          controller.initialize();
          incomingController.add((
            Role.bibRecorderV2,
            MessageEnvelope.wrapBibEntry(makeMsg(1, 101)),
          ));
          incomingController.add((
            Role.bibRecorderV2,
            MessageEnvelope.wrapBibEntry(makeMsg(2, 202)),
          ));
          fake.flushMicrotasks();

          controller.verify(1); // acted, not yet committed

          // Entry 1 is verified (not pending), entry 2 is still pending.
          expect(controller.pending, 1);
          expect(controller.confirmed, 0);
        });
      });
    });

    group('undo', () {
      BibEntryMessage makeMsg(int position, int bib) => BibEntryMessage(
            finishPosition: position,
            bib: bib,
            status: BibEntryStatus.resolved,
            timestamp: DateTime.now(),
          );

      test('undo cancels timer and reverts entry to pending', () async {
        final controller = VerifierController(session: mockSession, haptic: mockHaptic);
        controller.initialize();
        incomingController.add((
          Role.bibRecorderV2,
          MessageEnvelope.wrapBibEntry(makeMsg(1, 101)),
        ));
        await Future.microtask(() {});

        controller.verify(1);
        expect(controller.entries.first.status, VerificationStatus.verified);

        controller.undo(1);

        expect(controller.entries.first.status, VerificationStatus.pending);
      });

      test('undo restores pending count', () async {
        final controller = VerifierController(session: mockSession, haptic: mockHaptic);
        controller.initialize();
        incomingController.add((
          Role.bibRecorderV2,
          MessageEnvelope.wrapBibEntry(makeMsg(1, 101)),
        ));
        await Future.microtask(() {});

        controller.verify(1);
        expect(controller.pending, 0);

        controller.undo(1);

        expect(controller.pending, 1);
      });

      test('undo prevents entry from being committed to history', () {
        fakeAsync((fake) {
          final controller = VerifierController(session: mockSession, haptic: mockHaptic);
          controller.initialize();
          incomingController.add((
            Role.bibRecorderV2,
            MessageEnvelope.wrapBibEntry(makeMsg(1, 101)),
          ));
          fake.flushMicrotasks();

          controller.verify(1);
          controller.undo(1);

          // Advance past 3s — timer was cancelled so entry stays in entries.
          fake.elapse(const Duration(seconds: 5));

          expect(controller.entries.first.status, VerificationStatus.pending);
          expect(controller.confirmed, 0);
        });
      });

      test('undo after entry committed is a no-op', () {
        fakeAsync((fake) {
          final controller = VerifierController(session: mockSession, haptic: mockHaptic);
          controller.initialize();
          incomingController.add((
            Role.bibRecorderV2,
            MessageEnvelope.wrapBibEntry(makeMsg(1, 101)),
          ));
          fake.flushMicrotasks();

          controller.verify(1);
          fake.elapse(const Duration(seconds: 3)); // entry committed to history
          expect(controller.confirmed, 1);
          expect(controller.entries, isEmpty);

          // undo after commit — entry is gone from entries, no-op
          controller.undo(1);

          expect(controller.confirmed, 1);
          expect(controller.entries, isEmpty);
        });
      });
    });

    group('leaveRace', () {
      test('clears entries, history, and sets isInRace to false', () async {
        final controller = VerifierController(session: mockSession, haptic: mockHaptic);
        controller.initialize();
        controller.joinRace(raceId: 1);
        incomingController.add((
          Role.bibRecorderV2,
          MessageEnvelope.wrapBibEntry(BibEntryMessage(
            finishPosition: 1,
            bib: 101,
            status: BibEntryStatus.resolved,
            timestamp: DateTime.now(),
          )),
        ));
        await Future.microtask(() {});

        expect(controller.entries, isNotEmpty);
        controller.leaveRace();

        expect(controller.entries, isEmpty);
        expect(controller.isInRace, isFalse);
      });

      test('cancels pending timers so no commits fire after leave', () {
        fakeAsync((fake) {
          final controller = VerifierController(session: mockSession, haptic: mockHaptic);
          controller.initialize();
          incomingController.add((
            Role.bibRecorderV2,
            MessageEnvelope.wrapBibEntry(BibEntryMessage(
              finishPosition: 1,
              bib: 101,
              status: BibEntryStatus.resolved,
              timestamp: DateTime.now(),
            )),
          ));
          fake.flushMicrotasks();

          controller.verify(1);
          controller.leaveRace(); // cancels timers

          fake.elapse(const Duration(seconds: 5));

          // Entries and history are both cleared — no timer fired.
          expect(controller.entries, isEmpty);
          expect(controller.confirmed, 0);
        });
      });
    });

    group('processLoadedRaceData', () {
      test('returns Failure when data cannot be parsed', () async {
        final controller = VerifierController(storage: mockStorage, haptic: mockHaptic);

        final result = await controller.processLoadedRaceData('not valid json');

        expect(result, isA<Failure<void>>());
      });

      test('returns Failure when runner section is invalid', () async {
        final controller = VerifierController(storage: mockStorage, haptic: mockHaptic);
        final data = '${testRace.encode()}---invalid-runner-data';

        final result = await controller.processLoadedRaceData(data);

        expect(result, isA<Failure<void>>());
      });

      test('returns Failure when saveNewRace fails', () async {
        when(mockStorage.saveNewRace(any)).thenAnswer(
          (_) async => Failure<void>(const AppError(userMessage: 'Save failed')),
        );
        final controller = VerifierController(storage: mockStorage, haptic: mockHaptic);

        final result = await controller.processLoadedRaceData(testRace.encode());

        expect(result, isA<Failure<void>>());
        expect((result as Failure).error.userMessage, 'Save failed');
      });

      test('returns Success and calls saveNewRace on valid data without runners', () async {
        final controller = VerifierController(storage: mockStorage, haptic: mockHaptic);

        final result = await controller.processLoadedRaceData(testRace.encode());

        expect(result, isA<Success<void>>());
        verify(mockStorage.saveNewRace(any)).called(1);
        verifyNever(mockStorage.saveRunners(any, any));
      });

      test('returns Success and calls saveRunners on valid data with runners', () async {
        final controller = VerifierController(storage: mockStorage, haptic: mockHaptic);
        final data = '${testRace.encode()}---$validRunnerJson';

        final result = await controller.processLoadedRaceData(data);

        expect(result, isA<Success<void>>());
        verify(mockStorage.saveNewRace(any)).called(1);
        verify(mockStorage.saveRunners(any, any)).called(1);
      });

      test('returns Failure when storage is null', () async {
        final controller = VerifierController(haptic: mockHaptic);

        final result = await controller.processLoadedRaceData(testRace.encode());

        expect(result, isA<Failure<void>>());
      });
    });

    group('stats', () {
      test('confirmed / wrong / skipped only count committed entries', () {
        fakeAsync((fake) {
          final controller = VerifierController(session: mockSession, haptic: mockHaptic);
          controller.initialize();
          for (final pos in [1, 2, 3]) {
            incomingController.add((
              Role.bibRecorderV2,
              MessageEnvelope.wrapBibEntry(BibEntryMessage(
                finishPosition: pos,
                bib: 100 + pos,
                status: BibEntryStatus.resolved,
                timestamp: DateTime.now(),
              )),
            ));
          }
          fake.flushMicrotasks();

          controller.verify(1);
          controller.flag(2);
          controller.skip(3);

          // Before timer fires — nothing committed yet.
          expect(controller.confirmed, 0);
          expect(controller.wrong, 0);
          expect(controller.skipped, 0);

          fake.elapse(const Duration(seconds: 3));

          expect(controller.confirmed, 1);
          expect(controller.wrong, 1);
          expect(controller.skipped, 1);
        });
      });

      test('pending only counts genuinely pending entries', () {
        fakeAsync((fake) {
          final controller = VerifierController(session: mockSession, haptic: mockHaptic);
          controller.initialize();
          for (final pos in [1, 2, 3]) {
            incomingController.add((
              Role.bibRecorderV2,
              MessageEnvelope.wrapBibEntry(BibEntryMessage(
                finishPosition: pos,
                bib: 100 + pos,
                status: BibEntryStatus.resolved,
                timestamp: DateTime.now(),
              )),
            ));
          }
          fake.flushMicrotasks();

          controller.verify(1); // acted, not pending
          controller.skip(2);   // acted, not pending

          expect(controller.pending, 1); // only entry 3
        });
      });
    });

    group('attachSession', () {
      test('subscribes to incoming messages after construction without session',
          () async {
        final controller = VerifierController(haptic: mockHaptic);

        controller.attachSession(mockSession);

        incomingController.add((
          Role.bibRecorderV2,
          MessageEnvelope.wrapBibEntry(BibEntryMessage(
            finishPosition: 1,
            bib: 77,
            status: BibEntryStatus.resolved,
            timestamp: DateTime.now(),
          )),
        ));

        await Future.microtask(() {});

        expect(controller.entries.length, 1);
        expect(controller.entries.first.bib, 77);
      });

      test('replaces prior session subscription without leaking', () async {
        final secondController =
            StreamController<(Role, MessageEnvelope)>.broadcast();
        final secondSession = MockP2PSessionService();
        when(secondSession.incomingMessages)
            .thenAnswer((_) => secondController.stream);

        final controller = VerifierController(session: mockSession, haptic: mockHaptic);
        controller.initialize();

        // Replace with second session.
        controller.attachSession(secondSession);

        // Message on old stream — should be ignored.
        incomingController.add((
          Role.bibRecorderV2,
          MessageEnvelope.wrapBibEntry(BibEntryMessage(
            finishPosition: 1,
            bib: 88,
            status: BibEntryStatus.resolved,
            timestamp: DateTime.now(),
          )),
        ));

        await Future.microtask(() {});

        // Entry should not appear — old subscription was cancelled.
        expect(controller.entries, isEmpty);

        await secondController.close();
      });
    });

    group('haptics', () {
      BibEntryMessage makeMsg(int position, int bib) => BibEntryMessage(
            finishPosition: position,
            bib: bib,
            status: BibEntryStatus.resolved,
            timestamp: DateTime.now(),
          );

      Future<VerifierController> makeControllerWithEntry(int position, int bib) async {
        final controller = VerifierController(session: mockSession, haptic: mockHaptic);
        controller.initialize();
        incomingController.add((Role.bibRecorderV2, MessageEnvelope.wrapBibEntry(makeMsg(position, bib))));
        await Future.microtask(() {});
        return controller;
      }

      test('verify calls lightImpact', () async {
        final controller = await makeControllerWithEntry(1, 101);
        controller.verify(1);
        verify(mockHaptic.lightImpact()).called(1);
        verifyNever(mockHaptic.vibrate());
      });

      test('flag calls vibrate', () async {
        final controller = await makeControllerWithEntry(2, 202);
        controller.flag(2);
        verify(mockHaptic.vibrate()).called(1);
        verifyNever(mockHaptic.lightImpact());
      });

      test('skip calls lightImpact', () async {
        final controller = await makeControllerWithEntry(3, 303);
        controller.skip(3);
        verify(mockHaptic.lightImpact()).called(1);
        verifyNever(mockHaptic.vibrate());
      });
    });
  });
}
