import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/controller/fixer_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/fixer_entry.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/haptic_feedback_service.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

import 'fixer_controller_test.mocks.dart';

@GenerateMocks([P2PSessionService, IAssistantStorageService, IHapticFeedback])
void main() {
  setUpAll(() {
    provideDummy<Result<void>>(Failure<void>(const AppError(userMessage: '')));
    provideDummy<Result<List<Runner>>>(const Success([]));
    provideDummy<Result<List<RaceRecord>>>(const Success([]));
    provideDummy<Result<List<FixerEntry>>>(const Success([]));
    provideDummy<Runner>(Runner(raceId: 0, bibNumber: '', createdAt: DateTime(2026)));
  });

  late MockP2PSessionService mockSession;
  late MockIAssistantStorageService mockStorage;
  late MockIHapticFeedback mockHaptic;
  late StreamController<(Role, MessageEnvelope)> incomingController;
  final controllers = <FixerController>[];

  setUp(() {
    mockSession = MockP2PSessionService();
    mockStorage = MockIAssistantStorageService();
    mockHaptic = MockIHapticFeedback();
    incomingController =
        StreamController<(Role, MessageEnvelope)>.broadcast();

    when(mockSession.incomingMessages)
        .thenAnswer((_) => incomingController.stream);
    when(mockSession.sendMessage(any, any)).thenAnswer((_) => Future.value());
    when(mockHaptic.vibrate()).thenAnswer((_) async {});
    when(mockHaptic.lightImpact()).thenAnswer((_) async {});
    when(mockStorage.getRaces(any))
        .thenAnswer((_) async => const Success<List<RaceRecord>>([]));
    when(mockStorage.getRunners(any))
        .thenAnswer((_) async => const Success<List<Runner>>([]));
    when(mockStorage.updateBibRecordValue(any, any, any))
        .thenAnswer((_) async => const Success<void>(null));
    when(mockStorage.saveRunner(any))
        .thenAnswer((_) async => const Success<void>(null));
    when(mockStorage.getFixerEntries(any))
        .thenAnswer((_) async => const Success<List<FixerEntry>>([]));
    when(mockStorage.saveFixerEntry(any, any))
        .thenAnswer((_) async => const Success<void>(null));
    when(mockStorage.updateFixerEntryResolution(
      any, any,
      isResolved: anyNamed('isResolved'),
      correctedBib: anyNamed('correctedBib'),
      resolvedName: anyNamed('resolvedName'),
      isNewRunner: anyNamed('isNewRunner'),
      correctionType: anyNamed('correctionType'),
    )).thenAnswer((_) async => const Success<void>(null));
  });

  tearDown(() async {
    for (final c in controllers) {
      c.dispose();
    }
    controllers.clear();
    await incomingController.close();
  });

  FixerController makeController({
    P2PSessionService? session,
    IAssistantStorageService? storage,
    IHapticFeedback? haptic,
    int raceId = 1,
  }) {
    final controller = FixerController(
      storage: storage ?? mockStorage,
      haptic: haptic ?? mockHaptic,
    );
    if (session != null) {
      controller.attachSession(session, raceId: raceId);
    }
    controllers.add(controller);
    return controller;
  }

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

      test('malformed verifierFlag payload is dropped and stream listener remains alive', () async {
        final controller = makeController(session: mockSession);
        controller.initialize();

        // Malformed: missing required fields — fromJson will throw.
        incomingController.add((
          Role.verifier,
          MessageEnvelope(
            type: MessageType.verifierFlag,
            version: messageSchemaVersion,
            payload: const {'bad_field': 'garbage'},
          ),
        ));
        await Future.microtask(() {});

        expect(controller.queue, isEmpty);

        // Subsequent valid message is still processed — listener still alive.
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
        expect(controller.queue.first.bib, 101);
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

      test('sends FixerCorrectionMessage with null correctedBib when newBib is null', () async {
        final controller = makeController(session: mockSession);
        controller.initialize();

        incomingController.add((
          Role.verifier,
          MessageEnvelope.wrapVerifierFlag(VerifierFlagMessage(
            entry: BibEntryMessage(
              finishPosition: 5,
              bib: 177,
              status: BibEntryStatus.unknown,
              timestamp: DateTime.now(),
            ),
            reason: FlagReason.unknown,
          )),
        ));
        await Future.microtask(() {});

        controller.resolveAsNewRunner(5);

        final captured =
            verify(mockSession.sendMessage(Role.bibRecorderV2, captureAny))
                .captured;
        final msg =
            (captured.last as MessageEnvelope).decode() as FixerCorrectionMessage;
        expect(msg.correctionType, CorrectionType.newRunner);
        expect(msg.correctedBib, isNull);
        expect(msg.originalBib, 177);
      });

      test('does not send message when no session is set', () async {
        // Pre-populate storage with a fixer entry so the queue is not empty.
        when(mockStorage.getFixerEntries(any)).thenAnswer((_) async =>
            const Success<List<FixerEntry>>([
              FixerEntry(
                id: 1,
                position: 1,
                bib: 101,
                reason: FixReason.unknown,
              ),
            ]));

        final controller = makeController();
        await controller.joinRace();

        controller.resolveAsNewRunner(1, name: 'New Runner');

        verifyNever(mockSession.sendMessage(any, any));
      });
    });

    group('incoming VerifierFlagMessage uses entryId for FixerEntry.id (XCE-522)', () {
      test('FixerEntry.id uses entryId from BibEntryMessage when present', () async {
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
              entryId: 1711000000000,
            ),
            reason: FlagReason.unknown,
          )),
        ));
        await Future.microtask(() {});

        expect(controller.queue.first.id, 1711000000000);
        expect(controller.queue.first.position, 1);
      });

      test('FixerEntry.id falls back to finishPosition when entryId is absent', () async {
        final controller = makeController(session: mockSession);
        controller.initialize();

        incomingController.add((
          Role.verifier,
          MessageEnvelope.wrapVerifierFlag(VerifierFlagMessage(
            entry: BibEntryMessage(
              finishPosition: 7,
              bib: 202,
              status: BibEntryStatus.duplicate,
              timestamp: DateTime.now(),
            ),
            reason: FlagReason.duplicate,
          )),
        ));
        await Future.microtask(() {});

        expect(controller.queue.first.id, 7);
        expect(controller.queue.first.position, 7);
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

    group('resolveWithRunner state', () {
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
            reason: FlagReason.wrongName,
          )),
        ));
        await Future.microtask(() {});
        return controller;
      }

      test('marks entry as resolved', () async {
        final controller =
            await makeControllerWithEntry(finishPosition: 1, bib: 107);
        final runner = Runner(
          raceId: 1,
          bibNumber: '110',
          name: 'Ryan Smith',
          createdAt: DateTime(2026),
        );

        controller.resolveWithRunner(1, runner);

        expect(controller.queue.first.isResolved, isTrue);
      });

      test('sets correctedBib from runner', () async {
        final controller =
            await makeControllerWithEntry(finishPosition: 1, bib: 107);
        final runner = Runner(
          raceId: 1,
          bibNumber: '110',
          createdAt: DateTime(2026),
        );

        controller.resolveWithRunner(1, runner);

        expect(controller.queue.first.correctedBib, 110);
      });

      test('sets resolvedName from runner name', () async {
        final controller =
            await makeControllerWithEntry(finishPosition: 1, bib: 107);
        final runner = Runner(
          raceId: 1,
          bibNumber: '110',
          name: 'Ryan Smith',
          createdAt: DateTime(2026),
        );

        controller.resolveWithRunner(1, runner);

        expect(controller.queue.first.resolvedName, 'Ryan Smith');
      });

      test('decrements unresolvedCount', () async {
        final controller =
            await makeControllerWithEntry(finishPosition: 1, bib: 107);
        final runner = Runner(
          raceId: 1,
          bibNumber: '110',
          createdAt: DateTime(2026),
        );
        expect(controller.unresolvedCount, 1);

        controller.resolveWithRunner(1, runner);

        expect(controller.unresolvedCount, 0);
      });

      test('is a no-op for unknown entryId', () async {
        final controller =
            await makeControllerWithEntry(finishPosition: 1, bib: 107);
        final runner = Runner(
          raceId: 1,
          bibNumber: '110',
          createdAt: DateTime(2026),
        );

        controller.resolveWithRunner(999, runner); // unknown id

        expect(controller.queue.first.isResolved, isFalse);
      });
    });

    group('resolveWithBib state', () {
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
              status: BibEntryStatus.duplicate,
              timestamp: DateTime.now(),
            ),
            reason: FlagReason.duplicate,
          )),
        ));
        await Future.microtask(() {});
        return controller;
      }

      test('marks entry as resolved', () async {
        final controller =
            await makeControllerWithEntry(finishPosition: 2, bib: 105);

        controller.resolveWithBib(2, 115);

        expect(controller.queue.first.isResolved, isTrue);
      });

      test('sets correctedBib to the new value', () async {
        final controller =
            await makeControllerWithEntry(finishPosition: 2, bib: 105);

        controller.resolveWithBib(2, 115);

        expect(controller.queue.first.correctedBib, 115);
      });

      test('decrements unresolvedCount', () async {
        final controller =
            await makeControllerWithEntry(finishPosition: 2, bib: 105);
        expect(controller.unresolvedCount, 1);

        controller.resolveWithBib(2, 115);

        expect(controller.unresolvedCount, 0);
      });

      test('is a no-op for unknown entryId', () async {
        final controller =
            await makeControllerWithEntry(finishPosition: 2, bib: 105);

        controller.resolveWithBib(999, 115);

        expect(controller.queue.first.isResolved, isFalse);
      });
    });

    group('resolveAsNewRunner state', () {
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

      test('marks entry as resolved with isNewRunner true', () async {
        final controller =
            await makeControllerWithEntry(finishPosition: 3, bib: 199);

        controller.resolveAsNewRunner(3, name: 'Jane Doe', newBib: 200);

        expect(controller.queue.first.isResolved, isTrue);
        expect(controller.queue.first.isNewRunner, isTrue);
      });

      test('sets resolvedName when name provided', () async {
        final controller =
            await makeControllerWithEntry(finishPosition: 3, bib: 199);

        controller.resolveAsNewRunner(3, name: 'Jane Doe');

        expect(controller.queue.first.resolvedName, 'Jane Doe');
      });

      test('sets correctedBib when newBib provided', () async {
        final controller =
            await makeControllerWithEntry(finishPosition: 3, bib: 199);

        controller.resolveAsNewRunner(3, newBib: 205);

        expect(controller.queue.first.correctedBib, 205);
      });

      test('correctedBib is null when no newBib provided', () async {
        final controller =
            await makeControllerWithEntry(finishPosition: 3, bib: 199);

        controller.resolveAsNewRunner(3);

        expect(controller.queue.first.correctedBib, isNull);
      });

      test('is a no-op for unknown entryId', () async {
        final controller =
            await makeControllerWithEntry(finishPosition: 3, bib: 199);

        controller.resolveAsNewRunner(999);

        expect(controller.queue.first.isResolved, isFalse);
      });

      test('decrements unresolvedCount', () async {
        final controller =
            await makeControllerWithEntry(finishPosition: 3, bib: 199);
        expect(controller.unresolvedCount, 1);

        controller.resolveAsNewRunner(3);

        expect(controller.unresolvedCount, 0);
      });
    });

    group('search', () {
      Future<FixerController> makeControllerWithRunners(
          List<Runner> runners) async {
        when(mockStorage.getRunners(any)).thenAnswer(
          (_) async => Success<List<Runner>>(runners),
        );
        final controller = makeController();
        controller.initialize();
        await controller.joinRace();
        return controller;
      }

      Runner makeRunner(String bib, String name) => Runner(
            raceId: 1,
            bibNumber: bib,
            name: name,
            createdAt: DateTime(2026),
          );

      test('empty query clears results', () async {
        final controller = await makeControllerWithRunners([
          makeRunner('101', 'Alice Smith'),
        ]);
        controller.search('alice');
        expect(controller.searchResults, isNotEmpty);

        controller.search('');
        expect(controller.searchResults, isEmpty);
        expect(controller.searchQuery, '');
      });

      test('whitespace-only query clears results', () async {
        final controller = await makeControllerWithRunners([
          makeRunner('101', 'Alice Smith'),
        ]);
        controller.search('alice');
        controller.search('   ');
        expect(controller.searchResults, isEmpty);
      });

      test('results are capped at 5', () async {
        final runners = List.generate(
          8,
          (i) => makeRunner('${100 + i}', 'Alice Runner $i'),
        );
        final controller = await makeControllerWithRunners(runners);
        controller.search('alice');
        expect(controller.searchResults.length, lessThanOrEqualTo(5));
      });

      test('results ranked by score descending (exact bib scores highest)', () async {
        final controller = await makeControllerWithRunners([
          makeRunner('101', 'Alice Smith'),  // exact name match for 'alice smith'
          makeRunner('999', 'Bob Jones'),
          makeRunner('alice', 'Carol White'), // bib matches query 'alice'
        ]);

        controller.search('alice');

        // The runner with bib 'alice' should score higher (exact bib = 1.0)
        // than the runner with name 'Alice Smith' (name substring = 0.8).
        expect(
          controller.searchResults.first.bibNumber,
          'alice',
        );
      });

      test('exact bib match returned first', () async {
        final controller = await makeControllerWithRunners([
          makeRunner('105', 'Alice Johnson'),
          makeRunner('200', 'Runner Two'),
        ]);

        controller.search('105');

        expect(controller.searchResults.first.bibNumber, '105');
      });
    });

    group('clearSearch', () {
      test('clears query and results', () async {
        when(mockStorage.getRunners(any)).thenAnswer(
          (_) async => Success<List<Runner>>([
            Runner(
              raceId: 1,
              bibNumber: '105',
              name: 'Alice Johnson',
              createdAt: DateTime(2026),
            ),
          ]),
        );
        final controller = makeController();
        await controller.joinRace();
        controller.search('alice');
        expect(controller.searchResults, isNotEmpty);

        controller.clearSearch();

        expect(controller.searchQuery, '');
        expect(controller.searchResults, isEmpty);
      });
    });

    group('leaveRace', () {
      test('clears queue, runners, search state, and isInRace', () async {
        final controller = makeController(session: mockSession);
        controller.initialize();
        await controller.joinRace();

        incomingController.add((
          Role.verifier,
          MessageEnvelope.wrapVerifierFlag(VerifierFlagMessage(
            entry: BibEntryMessage(
              finishPosition: 1,
              bib: 101,
              status: BibEntryStatus.unknown,
              timestamp: DateTime.now(),
            ),
            reason: FlagReason.unknown,
          )),
        ));
        await Future.microtask(() {});

        controller.search('101');
        expect(controller.isInRace, isTrue);
        expect(controller.queue, isNotEmpty);

        controller.leaveRace();

        expect(controller.queue, isEmpty);
        expect(controller.isInRace, isFalse);
        expect(controller.searchResults, isEmpty);
        expect(controller.searchQuery, '');
        expect(controller.unresolvedCount, 0);
      });
    });

    group('resolve methods storage behaviour (XCE-378, XCE-524)', () {
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

      test('resolveWithRunner does not call updateBibRecordValue', () async {
        final controller = await makeControllerWithEntry(finishPosition: 1, bib: 107);
        final runner = Runner(
          raceId: 1,
          bibNumber: '110',
          name: 'Ryan Smith',
          createdAt: DateTime(2026),
        );

        controller.resolveWithRunner(1, runner);
        await Future.microtask(() {});

        verifyNever(mockStorage.updateBibRecordValue(any, any, any));
      });

      test('resolveWithBib does not call updateBibRecordValue', () async {
        final controller = await makeControllerWithEntry(finishPosition: 2, bib: 105);

        controller.resolveWithBib(2, 115);
        await Future.microtask(() {});

        verifyNever(mockStorage.updateBibRecordValue(any, any, any));
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

      test('resolveAsNewRunner does not call updateBibRecordValue', () async {
        final controller = await makeControllerWithEntry(finishPosition: 3, bib: 199);

        controller.resolveAsNewRunner(3, name: 'Jane Doe', newBib: 200);
        await Future.microtask(() {});

        verifyNever(mockStorage.updateBibRecordValue(any, any, any));
      });

      test('resolveAsNewRunner uses original bib as bibNumber when newBib is null', () async {
        final controller = await makeControllerWithEntry(finishPosition: 4, bib: 188);

        controller.resolveAsNewRunner(4, name: 'Unknown');
        await Future.microtask(() {});

        final captured = verify(mockStorage.saveRunner(captureAny)).captured;
        final runner = captured.single as Runner;
        expect(runner.bibNumber, '188');
      });
    });

    group('processLoadedRaceData', () {
      final testRace = RaceRecord(
        raceId: 1,
        date: DateTime(2026),
        name: 'Test Race',
        type: 'fixer',
      );
      const validRunnerJson = '{"teams":["EAG"],"r":[["42","Alice",0,"10"]]}';

      setUp(() {
        when(mockStorage.saveNewRace(any))
            .thenAnswer((_) async => const Success<void>(null));
        when(mockStorage.saveRunners(any, any))
            .thenAnswer((_) async => const Success<void>(null));
      });

      test('returns Failure when data cannot be parsed', () async {
        final controller = makeController();

        final result = await controller.processLoadedRaceData('not valid json');

        expect(result, isA<Failure<void>>());
      });

      test('returns Failure when runner section is invalid', () async {
        final controller = makeController();
        final data = '${testRace.encode()}---invalid-runner-data';

        final result = await controller.processLoadedRaceData(data);

        expect(result, isA<Failure<void>>());
      });

      test('returns Failure when saveNewRace fails', () async {
        when(mockStorage.saveNewRace(any)).thenAnswer(
          (_) async => Failure<void>(const AppError(userMessage: 'Save failed')),
        );
        final controller = makeController();

        final result = await controller.processLoadedRaceData(testRace.encode());

        expect(result, isA<Failure<void>>());
        expect((result as Failure).error.userMessage, 'Save failed');
      });

      test('returns Success and calls saveNewRace on valid data without runners', () async {
        final controller = makeController();

        final result = await controller.processLoadedRaceData(testRace.encode());

        expect(result, isA<Success<void>>());
        verify(mockStorage.saveNewRace(any)).called(1);
        verifyNever(mockStorage.saveRunners(any, any));
      });

      test('returns Success and calls saveRunners on valid data with runners', () async {
        final controller = makeController();
        final data = '${testRace.encode()}---$validRunnerJson';

        final result = await controller.processLoadedRaceData(data);

        expect(result, isA<Success<void>>());
        verify(mockStorage.saveNewRace(any)).called(1);
        verify(mockStorage.saveRunners(any, any)).called(1);
      });
    });

    group('persistence', () {
      test('saves entry to storage when received from Verifier', () async {
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

        verify(mockStorage.saveFixerEntry(any, any)).called(1);
      });

      test('persists resolution when resolveWithRunner is called', () async {
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

        controller.resolveWithRunner(
          1,
          Runner(raceId: 1, bibNumber: '110', name: 'Ryan', createdAt: DateTime(2026)),
        );

        verify(mockStorage.updateFixerEntryResolution(
          any, 1,
          isResolved: true,
          correctedBib: 110,
          resolvedName: 'Ryan',
          isNewRunner: false,
          correctionType: 'matched',
        )).called(1);
      });

      test('persists resolution when resolveWithBib is called', () async {
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

        verify(mockStorage.updateFixerEntryResolution(
          any, 2,
          isResolved: true,
          correctedBib: 115,
          isNewRunner: false,
          correctionType: 'bibCorrected',
        )).called(1);
      });

      test('persists resolution when resolveAsNewRunner is called', () async {
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
            reason: FlagReason.unknown,
          )),
        ));
        await Future.microtask(() {});

        controller.resolveAsNewRunner(3, name: 'Jane Doe', newBib: 200);

        verify(mockStorage.updateFixerEntryResolution(
          any, 3,
          isResolved: true,
          correctedBib: 200,
          resolvedName: 'Jane Doe',
          isNewRunner: true,
          correctionType: 'newRunner',
        )).called(1);
      });

      test('loads persisted entries on joinRace for crash recovery', () async {
        final persisted = [
          const FixerEntry(id: 1, position: 1, bib: 101, reason: FixReason.unknown),
          const FixerEntry(id: 2, position: 2, bib: 102, reason: FixReason.duplicate, isResolved: true, correctedBib: 202),
        ];
        when(mockStorage.getFixerEntries(any))
            .thenAnswer((_) async => Success(persisted));

        final controller = makeController(session: mockSession);
        controller.initialize();
        await controller.joinRace();

        expect(controller.queue.length, 2);
        expect(controller.unresolvedCount, 1);
      });
    });

    group('haptics', () {
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
            reason: FlagReason.wrongName,
          )),
        ));
        await Future.microtask(() {});
        return controller;
      }

      test('vibrates when a new entry arrives in the queue', () async {
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

        verify(mockHaptic.vibrate()).called(1);
        verifyNever(mockHaptic.lightImpact());
      });

      test('resolveWithRunner calls lightImpact', () async {
        final controller = await makeControllerWithEntry(finishPosition: 1, bib: 107);
        final runner = Runner(raceId: 1, bibNumber: '110', createdAt: DateTime(2026));
        clearInteractions(mockHaptic);

        controller.resolveWithRunner(1, runner);

        verify(mockHaptic.lightImpact()).called(1);
        verifyNever(mockHaptic.vibrate());
      });

      test('resolveWithBib calls lightImpact', () async {
        final controller = await makeControllerWithEntry(finishPosition: 2, bib: 105);
        clearInteractions(mockHaptic);

        controller.resolveWithBib(2, 115);

        verify(mockHaptic.lightImpact()).called(1);
        verifyNever(mockHaptic.vibrate());
      });

      test('resolveAsNewRunner calls lightImpact', () async {
        final controller = await makeControllerWithEntry(finishPosition: 3, bib: 199);
        clearInteractions(mockHaptic);

        controller.resolveAsNewRunner(3, name: 'Jane Doe', newBib: 200);

        verify(mockHaptic.lightImpact()).called(1);
        verifyNever(mockHaptic.vibrate());
      });
    });
  });
}
