import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/verifier_entry.dart';

void main() {
  group('VerifierEntry.fromMap', () {
    test('restores entryId so flags sent after a restart carry it', () {
      final entry = VerifierEntry(
        id: 7,
        entryId: 7,
        position: 3,
        bib: 105,
        status: VerificationStatus.pending,
      );

      final restored = VerifierEntry.fromMap(entry.toMap(1));

      expect(restored.id, 7);
      expect(restored.entryId, 7);
      expect(restored.position, 3);
      expect(restored.bib, 105);
    });
  });
}
