import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/controller/fixer_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/bib_correction_message.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/fixer_entry.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/i_bib_correction_channel.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

import 'fixer_controller_test.mocks.dart';

@GenerateMocks([P2PSessionService, IBibCorrectionChannel, IAssistantStorageService])
void main() {
  setUpAll(() {
    provideDummy<Result<void>>(Failure<void>(const AppError(userMessage: '')));
    provideDummy<Result<List<Runner>>>(const Success([]));
    provideDummy<Result<List<RaceRecord>>>(const Success([]));
    provideDummy<Runner>(Runner(raceId: 0, bibNumber: '', createdAt: DateTime(2026)));
  });

  late MockP2PSessionService mockSession;
  late MockIAssistantStorageService mockStorage;
  late StreamController<(Role, MessageEnvelope)> incomingController;

  setUp(() {
    mockSession = MockP2PSessionService();
    mockStorage = MockIAssistantStorageService();
    incomingController =
        StreamController<(Role, MessageEnvelope)>.broadcast();

    when(mockSession.incomingMessages)
        .thenAnswer((_) => incomingController.stream);
    when(mockSession.sendMessage(any, any)).thenAnswer((_) => Future.value());
    when(mockStorage.getRunners(any))
        .thenAnswer((_) async => const Success<List<Runner>>([]));
    when(mockStorage.updateBibRecordValue(any, any, any))
        .thenAnswer((_) async => const Success<void>(null));
    when(mockStorage.saveRunner(any))
        .thenAnswer((_) async => const Success<void>(null));
  });

  tearDown(() async {
    await incomingController.close();
  });

  FixerController makeController({
    P2PSessionService? session,
    IBibCorrectionChannel? correctionChannel,
    IAssistantStorageService? storage,
    int raceId = 1,
  }) =>
      FixerController(
        storage: storage ?? mockStorage,
        raceId: raceId,
        session: session,
        correctionChannel: correctionChannel,
      );

  group('FixerController', () {
    group('initialize', () {
      test('subscribes to incoming messages when session is set', () async {
        final controller = makeController(session: mockSession);
        controller.initialize();

        incomingController.add((
          Role.verifier,
          MessageEnvelope.wrapVerifierFlag(VerifierFlagMessage(
            entry: BibEntryMessage(
              finishPosition: 1,
              bib: 101,
              status: BibEntryStatus.resolved,
              timestamp: DateTime.now(),
            ),
            reason: FlagReason.wrongName,
          )),
        ));

        await Future.microtask(() {});

        expect(controller.queue.length, 1);
      });
    });

    group('incoming VerifierFlagMessage', () {
      test('adds entry with verifierFlagged reason for wrongName', () async {
        final controller = makeController(session: mockSession);
        controller.initialize();

        incomingController.add((
          Role.verifier,
          MessageEnvelope.wrapVerifierFlag(VerifierFlagMessage(
            entry: BibEntryMessage(
              finishPosition: 5,
              bib: 202,
              status: BibEntryStatus.resolved,
              timestamp: DateTime.now(),
            ),
            reason: FlagReason.wrongName,
          )),
        ));

        await Future.microtask(() {});

        expect(controller.queue.length, 1);
        final entry = controller.queue.first;
        expect(entry.bib, 202);
        expect(entry.position, 5);
        expect(entry.reason, FixReason.verifierFlagged);
        expect(entry.isResolved, isFalse);
      });

      test('adds entry with unknown reason', () async {
        final controller = makeController(session: mockSession);
        controller.initialize();

        incomingController.add((
          Role.verifier,
          MessageEnvelope.wrapVerifierFlag(VerifierFlagMessage(
            entry: BibEntryMessage(
              finishPosition: 2,
              bib: 999,
              status: BibEntryStatus.unknown,
              timestamp: DateTime.now(),
            ),
            reason: FlagReason.unknown,
          )),
        ));

        await Future.microtask(() {});

        expect(controller.queue.first.reason, FixReason.unknown);
      });

      test('adds entry with duplicate reason', () async {
        final controller = makeController(session: mockSession);
        controller.initialize();

        incomingController.add((
          Role.verifier,
          MessageEnvelope.wrapVerifierFlag(VerifierFlagMessage(
            entry: BibEntryMessage(
              finishPosition: 3,
              bib: 107,
              status: BibEntryStatus.duplicate,
              timestamp: DateTime.now(),
            ),
            reason: FlagReason.duplicate,
          )),
        ));

        await Future.microtask(() {});

        expect(controller.queue.first.reason, FixReason.duplicate);
      });

      test('ignores non-verifierFlag message types', () async {
        final controller = makeController(session: mockSession);
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

        expect(controller.queue, isEmpty);
      });
    });

    group('resolveWithRunner', () {
      test('sends FixerCorrectionMessage with matched correction type', () async {
        final controller = makeController(session: mockSession);
        controller.initialize();

        incomingController.add((
          Role.verifier,
          MessageEnvelope.wrapVerifierFlag(VerifierFlagMessage(
            entry: BibEntryMessage(
              finishPosition: 1,
              bib: 107,
              status: BibEntryStatus.unknown,
              timestamp: DateTime.now(),
            ),
            reason: FlagReason.wrongName,
          )),
        ));
        await Future.microtask(() {});

        final runner = Runner(
          raceId: 1,
          bibNumber: '110',
          name: 'Ryan Smith',
          teamAbbreviation: 'ELK',
          createdAt: DateTime(2026),
        );
        controller.resolveWithRunner(1, runner);

        final captured =
            verify(mockSession.sendMessage(Role.bibRecorderV2, captureAny))
                .captured;
        final envelope = captured.last as MessageEnvelope;
        expect(envelope.type, MessageType.fixerCorrection);
        final msg = envelope.decode() as FixerCorrectionMessage;
        expect(msg.finishPosition, 1);
        expect(msg.originalBib, 107);
        expect(msg.correctedBib, 110);
        expect(msg.correctionType, CorrectionType.matched);
      });
    });

    group('resolveWithBib', () {
      test('sends FixerCorrectionMessage with bibCorrected correction type', () async {
        final controller = makeController(session: mockSession);
        controller.initialize();

        incomingController.add((
          Role.verifier,
          MessageEnvelope.wrapVerifierFlag(VerifierFlagMessage(
            entry: BibEntryMessage(
              finishPosition: 2,
              bib: 105,
              status: BibEntryStatus.duplicate,
              timestamp: DateTime.now(),
            ),
            reason: FlagReason.duplicate,
          )),
        ));
        await Future.microtask(() {});

        controller.resolveWithBib(2, 115);

        final captured =
            verify(mockSession.sendMessage(Role.bibRecorderV2, captureAny))
                .captured;
        final msg =
            (captured.last as MessageEnvelope).decode() as FixerCorrectionMessage;
        expect(msg.finishPosition, 2);
        expect(msg.originalBib, 105);
        expect(msg.correctedBib, 115);
        expect(msg.correctionType, CorrectionType.bibCorrected);
      });
    });

    group('resolveAsNewRunner', () {
      test('sends FixerCorrectionMessage with newRunner correction type', () async {
        final controller = makeController(session: mockSession);
        controller.initialize();

        incomingController.add((
          Role.verifier,
          MessageEnvelope.wrapVerifierFlag(VerifierFlagMessage(
            entry: BibEntryMessage(
              finishPosition: 3,
              bib: 199,
              status: BibEntryStatus.unknown,
              timestamp: DateTime.now(),
            ),
            reason: FlagReason.wrongName,
          )),
        ));
        await Future.microtask(() {});

        controller.resolveAsNewRunner(3, name: 'Unknown Runner', newBib: 199);

        final captured =
            verify(mockSession.sendMessage(Role.bibRecorderV2, captureAny))
                .captured;
        final msg =
            (captured.last as MessageEnvelope).decode() as FixerCorrectionMessage;
        expect(msg.correctionType, CorrectionType.newRunner);
        expect(msg.correctedBib, 199);
      });

      test('does not send message when no session is set', () async {
        final controller = makeController();
        await controller.joinRace();

        verifyNever(mockSession.sendMessage(any, any));
      });
    });

    group('IBibCorrectionChannel', () {
      late MockIBibCorrectionChannel mockChannel;

      setUp(() {
        mockChannel = MockIBibCorrectionChannel();
      });

      test('resolveWithRunner calls sendCorrection with correct fields', () async {
        final controller = makeController(
          session: mockSession,
          correctionChannel: mockChannel,
        );
        controller.initialize();

        incomingController.add((
          Role.verifier,
          MessageEnvelope.wrapVerifierFlag(VerifierFlagMessage(
            entry: BibEntryMessage(
              finishPosition: 1,
              bib: 107,
              status: BibEntryStatus.unknown,
              timestamp: DateTime.now(),
            ),
            reason: FlagReason.wrongName,
          )),
        ));
        await Future.microtask(() {});

        final runner = Runner(
          raceId: 1,
          bibNumber: '110',
          name: 'Ryan Smith',
          teamAbbreviation: 'ELK',
          createdAt: DateTime(2026),
        );
        controller.resolveWithRunner(1, runner);

        final captured =
            verify(mockChannel.sendCorrection(captureAny)).captured;
        final msg = captured.single as BibCorrectionMessage;
        expect(msg.entryId, 1);
        expect(msg.originalBib, 107);
        expect(msg.correctedBib, 110);
        expect(msg.resolvedName, 'Ryan Smith');
        expect(msg.isNewRunner, isFalse);
      });

      test('resolveWithBib calls sendCorrection with correct fields', () async {
        final controller = makeController(
          session: mockSession,
          correctionChannel: mockChannel,
        );
        controller.initialize();

        incomingController.add((
          Role.verifier,
          MessageEnvelope.wrapVerifierFlag(VerifierFlagMessage(
            entry: BibEntryMessage(
              finishPosition: 2,
              bib: 105,
              status: BibEntryStatus.duplicate,
              timestamp: DateTime.now(),
            ),
            reason: FlagReason.duplicate,
          )),
        ));
        await Future.microtask(() {});

        controller.resolveWithBib(2, 115);

        final captured =
            verify(mockChannel.sendCorrection(captureAny)).captured;
        final msg = captured.single as BibCorrectionMessage;
        expect(msg.entryId, 2);
        expect(msg.originalBib, 105);
        expect(msg.correctedBib, 115);
        expect(msg.resolvedName, isNull);
        expect(msg.isNewRunner, isFalse);
      });

      test('resolveAsNewRunner calls sendCorrection with isNewRunner true', () async {
        final controller = makeController(
          session: mockSession,
          correctionChannel: mockChannel,
        );
        controller.initialize();

        incomingController.add((
          Role.verifier,
          MessageEnvelope.wrapVerifierFlag(VerifierFlagMessage(
            entry: BibEntryMessage(
              finishPosition: 3,
              bib: 199,
              status: BibEntryStatus.unknown,
              timestamp: DateTime.now(),
            ),
            reason: FlagReason.wrongName,
          )),
        ));
        await Future.microtask(() {});

        controller.resolveAsNewRunner(3, name: 'Jane Doe', newBib: 200);

        final captured =
            verify(mockChannel.sendCorrection(captureAny)).captured;
        final msg = captured.single as BibCorrectionMessage;
        expect(msg.entryId, 3);
        expect(msg.originalBib, 199);
        expect(msg.correctedBib, 200);
        expect(msg.resolvedName, 'Jane Doe');
        expect(msg.isNewRunner, isTrue);
      });

      test('does not call sendCorrection when correctionChannel is null', () async {
        final controller = makeController(session: mockSession);
        controller.initialize();

        incomingController.add((
          Role.verifier,
          MessageEnvelope.wrapVerifierFlag(VerifierFlagMessage(
            entry: BibEntryMessage(
              finishPosition: 1,
              bib: 101,
              status: BibEntryStatus.unknown,
              timestamp: DateTime.now(),
            ),
            reason: FlagReason.wrongName,
          )),
        ));
        await Future.microtask(() {});

        controller.resolveWithBib(1, 102);

        verifyNever(mockChannel.sendCorrection(any));
      });
    });

    group('joinRace loads runner roster (XCE-377)', () {
      test('populates allRunners from storage and search returns matches', () async {
        final runner1 = Runner(
          raceId: 1,
          bibNumber: '105',
          name: 'Alex Johnson',
          createdAt: DateTime(2026),
        );
        final runner2 = Runner(
          raceId: 1,
          bibNumber: '107',
          name: 'Ryan Smith',
          createdAt: DateTime(2026),
        );
        when(mockStorage.getRunners(1))
            .thenAnswer((_) async => Success<List<Runner>>([runner1, runner2]));

        final controller = makeController(session: mockSession);
        controller.initialize();
        await controller.joinRace();

        controller.search('alex');

        expect(controller.searchResults, isNotEmpty);
        expect(controller.searchResults.any((r) => r.bibNumber == '105'), isTrue);
      });

      test('leaves roster empty and logs on storage failure', () async {
        when(mockStorage.getRunners(any)).thenAnswer(
          (_) async => Failure<List<Runner>>(
            const AppError(userMessage: 'Storage error'),
          ),
        );

        final controller = makeController(session: mockSession);
        controller.initialize();
        await controller.joinRace();

        controller.search('ryan');

        expect(controller.searchResults, isEmpty);
      });
    });

    group('resolve methods persist to storage (XCE-378)', () {
      Future<FixerController> makeControllerWithEntry({
        required int finishPosition,
        required int bib,
      }) async {
        final controller = makeController(session: mockSession);
        controller.initialize();

        incomingController.add((
          Role.verifier,
          MessageEnvelope.wrapVerifierFlag(VerifierFlagMessage(
            entry: BibEntryMessage(
              finishPosition: finishPosition,
              bib: bib,
              status: BibEntryStatus.unknown,
              timestamp: DateTime.now(),
            ),
            reason: FlagReason.unknown,
          )),
        ));
        await Future.microtask(() {});
        return controller;
      }

      test('resolveWithRunner calls updateBibRecordValue', () async {
        final controller = await makeControllerWithEntry(finishPosition: 1, bib: 107);
        final runner = Runner(
          raceId: 1,
          bibNumber: '110',
          name: 'Ryan Smith',
          createdAt: DateTime(2026),
        );

        controller.resolveWithRunner(1, runner);
        await Future.microtask(() {});

        verify(mockStorage.updateBibRecordValue(1, 1, '110')).called(1);
      });

      test('resolveWithBib calls updateBibRecordValue', () async {
        final controller = await makeControllerWithEntry(finishPosition: 2, bib: 105);

        controller.resolveWithBib(2, 115);
        await Future.microtask(() {});

        verify(mockStorage.updateBibRecordValue(1, 2, '115')).called(1);
      });

      test('resolveAsNewRunner calls saveRunner with correct bibNumber', () async {
        final controller = await makeControllerWithEntry(finishPosition: 3, bib: 199);

        controller.resolveAsNewRunner(3, name: 'Jane Doe', newBib: 200);
        await Future.microtask(() {});

        final captured = verify(mockStorage.saveRunner(captureAny)).captured;
        final runner = captured.single as Runner;
        expect(runner.bibNumber, '200');
        expect(runner.name, 'Jane Doe');
        expect(runner.raceId, 1);
      });

      test('resolveAsNewRunner also calls updateBibRecordValue when newBib is provided', () async {
        final controller = await makeControllerWithEntry(finishPosition: 3, bib: 199);

        controller.resolveAsNewRunner(3, name: 'Jane Doe', newBib: 200);
        await Future.microtask(() {});

        verify(mockStorage.updateBibRecordValue(1, 3, '200')).called(1);
      });

      test('resolveAsNewRunner uses entryId as bibNumber when newBib is null', () async {
        final controller = await makeControllerWithEntry(finishPosition: 4, bib: 188);

        controller.resolveAsNewRunner(4, name: 'Unknown');
        await Future.microtask(() {});

        final captured = verify(mockStorage.saveRunner(captureAny)).captured;
        final runner = captured.single as Runner;
        expect(runner.bibNumber, '4');
      });
    });
  });
}
