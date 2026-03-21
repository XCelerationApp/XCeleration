import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';

void main() {
  // ---------------------------------------------------------------------------
  // BibEntryMessage
  // ---------------------------------------------------------------------------

  group('BibEntryMessage', () {
    final timestamp = DateTime.utc(2026, 3, 20, 10, 30);

    BibEntryMessage makeEntry({
      int position = 1,
      int bib = 42,
      BibEntryStatus status = BibEntryStatus.resolved,
    }) =>
        BibEntryMessage(
          finishPosition: position,
          bib: bib,
          status: status,
          timestamp: timestamp,
        );

    group('toJson', () {
      test('serialises all fields', () {
        final json = makeEntry().toJson();

        expect(json['finish_position'], 1);
        expect(json['bib'], 42);
        expect(json['status'], 'resolved');
        expect(json['timestamp'], timestamp.toIso8601String());
      });

      test('serialises unknown status', () {
        expect(makeEntry(status: BibEntryStatus.unknown).toJson()['status'], 'unknown');
      });

      test('serialises duplicate status', () {
        expect(makeEntry(status: BibEntryStatus.duplicate).toJson()['status'], 'duplicate');
      });
    });

    group('fromJson', () {
      test('round-trips resolved entry', () {
        final original = makeEntry();
        final decoded = BibEntryMessage.fromJson(original.toJson());

        expect(decoded.finishPosition, original.finishPosition);
        expect(decoded.bib, original.bib);
        expect(decoded.status, BibEntryStatus.resolved);
        expect(decoded.timestamp, original.timestamp);
      });

      test('round-trips unknown status', () {
        final decoded = BibEntryMessage.fromJson(
          makeEntry(status: BibEntryStatus.unknown).toJson(),
        );
        expect(decoded.status, BibEntryStatus.unknown);
      });

      test('round-trips duplicate status', () {
        final decoded = BibEntryMessage.fromJson(
          makeEntry(status: BibEntryStatus.duplicate).toJson(),
        );
        expect(decoded.status, BibEntryStatus.duplicate);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // VerifierFlagMessage
  // ---------------------------------------------------------------------------

  group('VerifierFlagMessage', () {
    final entry = BibEntryMessage(
      finishPosition: 3,
      bib: 77,
      status: BibEntryStatus.unknown,
      timestamp: DateTime.utc(2026, 3, 20, 11, 0),
    );

    VerifierFlagMessage makeFlag({FlagReason reason = FlagReason.unknown}) =>
        VerifierFlagMessage(entry: entry, reason: reason);

    group('toJson', () {
      test('serialises wrongName reason as wrong_name', () {
        final json = makeFlag(reason: FlagReason.wrongName).toJson();
        expect(json['reason'], 'wrong_name');
      });

      test('serialises unknown reason', () {
        expect(makeFlag(reason: FlagReason.unknown).toJson()['reason'], 'unknown');
      });

      test('serialises duplicate reason', () {
        expect(makeFlag(reason: FlagReason.duplicate).toJson()['reason'], 'duplicate');
      });

      test('nests the bib entry payload', () {
        final json = makeFlag().toJson();
        expect(json['entry'], isA<Map<String, dynamic>>());
        expect((json['entry'] as Map)['bib'], 77);
      });
    });

    group('fromJson', () {
      test('round-trips wrongName reason', () {
        final decoded = VerifierFlagMessage.fromJson(
          makeFlag(reason: FlagReason.wrongName).toJson(),
        );
        expect(decoded.reason, FlagReason.wrongName);
        expect(decoded.entry.bib, 77);
      });

      test('round-trips unknown reason', () {
        final decoded = VerifierFlagMessage.fromJson(
          makeFlag(reason: FlagReason.unknown).toJson(),
        );
        expect(decoded.reason, FlagReason.unknown);
      });

      test('round-trips duplicate reason', () {
        final decoded = VerifierFlagMessage.fromJson(
          makeFlag(reason: FlagReason.duplicate).toJson(),
        );
        expect(decoded.reason, FlagReason.duplicate);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // FixerCorrectionMessage
  // ---------------------------------------------------------------------------

  group('FixerCorrectionMessage', () {
    FixerCorrectionMessage makeCorrection({
      int finishPosition = 5,
      int originalBib = 99,
      int correctedBib = 100,
      int? matchedRunnerId = 42,
      CorrectionType type = CorrectionType.matched,
    }) =>
        FixerCorrectionMessage(
          finishPosition: finishPosition,
          originalBib: originalBib,
          correctedBib: correctedBib,
          matchedRunnerId: matchedRunnerId,
          correctionType: type,
        );

    group('toJson', () {
      test('serialises matched correction type', () {
        expect(
          makeCorrection(type: CorrectionType.matched).toJson()['correction_type'],
          'matched',
        );
      });

      test('serialises bibCorrected as bib_corrected', () {
        expect(
          makeCorrection(type: CorrectionType.bibCorrected).toJson()['correction_type'],
          'bib_corrected',
        );
      });

      test('serialises newRunner as new_runner', () {
        expect(
          makeCorrection(type: CorrectionType.newRunner).toJson()['correction_type'],
          'new_runner',
        );
      });

      test('serialises null matchedRunnerId', () {
        final json = makeCorrection(matchedRunnerId: null).toJson();
        expect(json['matched_runner_id'], isNull);
      });

      test('serialises non-null matchedRunnerId', () {
        expect(makeCorrection().toJson()['matched_runner_id'], 42);
      });
    });

    group('fromJson', () {
      test('round-trips matched correction with runner ID', () {
        final decoded = FixerCorrectionMessage.fromJson(makeCorrection().toJson());

        expect(decoded.finishPosition, 5);
        expect(decoded.originalBib, 99);
        expect(decoded.correctedBib, 100);
        expect(decoded.matchedRunnerId, 42);
        expect(decoded.correctionType, CorrectionType.matched);
      });

      test('round-trips bib_corrected type', () {
        final decoded = FixerCorrectionMessage.fromJson(
          makeCorrection(type: CorrectionType.bibCorrected).toJson(),
        );
        expect(decoded.correctionType, CorrectionType.bibCorrected);
      });

      test('round-trips new_runner type with null runner ID', () {
        final decoded = FixerCorrectionMessage.fromJson(
          makeCorrection(type: CorrectionType.newRunner, matchedRunnerId: null).toJson(),
        );
        expect(decoded.correctionType, CorrectionType.newRunner);
        expect(decoded.matchedRunnerId, isNull);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // MessageEnvelope
  // ---------------------------------------------------------------------------

  group('MessageEnvelope', () {
    final bibEntry = BibEntryMessage(
      finishPosition: 1,
      bib: 55,
      status: BibEntryStatus.resolved,
      timestamp: DateTime.utc(2026, 3, 20, 9, 0),
    );

    final verifierFlag = VerifierFlagMessage(
      entry: bibEntry,
      reason: FlagReason.wrongName,
    );

    final fixerCorrection = FixerCorrectionMessage(
      finishPosition: 1,
      originalBib: 55,
      correctedBib: 56,
      correctionType: CorrectionType.bibCorrected,
    );

    group('toJson / fromJson', () {
      test('round-trips the envelope fields', () {
        final envelope = MessageEnvelope.wrapBibEntry(bibEntry);
        final decoded = MessageEnvelope.fromJson(envelope.toJson());

        expect(decoded.type, 'bib_entry');
        expect(decoded.version, messageSchemaVersion);
        expect(decoded.payload, isA<Map<String, dynamic>>());
      });
    });

    group('decode', () {
      test('decodes bib_entry envelope to BibEntryMessage', () {
        final envelope = MessageEnvelope.wrapBibEntry(bibEntry);
        final json = envelope.toJson();

        final received = MessageEnvelope.fromJson(json);
        final msg = received.decode();

        expect(msg, isA<BibEntryMessage>());
        final decoded = msg as BibEntryMessage;
        expect(decoded.bib, 55);
        expect(decoded.status, BibEntryStatus.resolved);
      });

      test('decodes verifier_flag envelope to VerifierFlagMessage', () {
        final envelope = MessageEnvelope.wrapVerifierFlag(verifierFlag);
        final msg = MessageEnvelope.fromJson(envelope.toJson()).decode();

        expect(msg, isA<VerifierFlagMessage>());
        final decoded = msg as VerifierFlagMessage;
        expect(decoded.reason, FlagReason.wrongName);
        expect(decoded.entry.bib, 55);
      });

      test('decodes fixer_correction envelope to FixerCorrectionMessage', () {
        final envelope = MessageEnvelope.wrapFixerCorrection(fixerCorrection);
        final msg = MessageEnvelope.fromJson(envelope.toJson()).decode();

        expect(msg, isA<FixerCorrectionMessage>());
        final decoded = msg as FixerCorrectionMessage;
        expect(decoded.correctedBib, 56);
        expect(decoded.correctionType, CorrectionType.bibCorrected);
      });

      test('throws ArgumentError for unknown type', () {
        final envelope = MessageEnvelope(
          type: 'unknown_type',
          version: messageSchemaVersion,
          payload: {},
        );
        expect(() => envelope.decode(), throwsArgumentError);
      });
    });
  });
}
