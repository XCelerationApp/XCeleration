import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/verifier_entry.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
import 'package:xceleration/assistant/finish_line_roles/verifier/controller/verifier_controller.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

import 'verifier_controller_test.mocks.dart';

@GenerateMocks([P2PSessionService])
void main() {
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

  group('VerifierController', () {
    group('initialize', () {
      test('subscribes to incoming messages when session is set', () async {
        final controller = VerifierController(session: mockSession);
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
        final controller = VerifierController(session: mockSession);
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
        final controller = VerifierController(session: mockSession);
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
        final controller = VerifierController(session: mockSession);
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
        final controller = VerifierController(session: mockSession);
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
        final controller = VerifierController(session: mockSession);
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
        final controller = VerifierController(session: mockSession);
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
    });

    group('flag', () {
      test('sends VerifierFlagMessage to fixer for entry with no bib flag', () async {
        final controller = VerifierController(session: mockSession);
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
        await Future.microtask(() {});

        controller.flag(1);

        final captured =
            verify(mockSession.sendMessage(Role.fixer, captureAny)).captured;
        final envelope = captured.last as MessageEnvelope;
        expect(envelope.type, MessageType.verifierFlag);
        final msg = envelope.decode() as VerifierFlagMessage;
        expect(msg.entry.bib, 101);
        expect(msg.entry.finishPosition, 1);
        expect(msg.reason, FlagReason.wrongName);
      });

      test('sends FlagReason.unknown for unknown-flagged entry', () async {
        final controller = VerifierController(session: mockSession);
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
        await Future.microtask(() {});

        controller.flag(2);

        final captured =
            verify(mockSession.sendMessage(Role.fixer, captureAny)).captured;
        final msg =
            (captured.last as MessageEnvelope).decode() as VerifierFlagMessage;
        expect(msg.reason, FlagReason.unknown);
      });

      test('sends FlagReason.duplicate for duplicate-flagged entry', () async {
        final controller = VerifierController(session: mockSession);
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
        await Future.microtask(() {});

        controller.flag(3);

        final captured =
            verify(mockSession.sendMessage(Role.fixer, captureAny)).captured;
        final msg =
            (captured.last as MessageEnvelope).decode() as VerifierFlagMessage;
        expect(msg.reason, FlagReason.duplicate);
      });

      test('does not send message when no session is set', () {
        final controller = VerifierController();
        controller.joinRace();

        // Without a session, flag should not call any sendMessage.
        verifyNever(mockSession.sendMessage(any, any));
      });
    });
  });
}
