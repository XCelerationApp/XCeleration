import 'package:xceleration/assistant/finish_line_roles/shared/models/bib_correction_message.dart';

/// Abstraction over the channel used by [FixerController] to emit corrections.
///
/// Production code will wire up a concrete implementation that wraps the
/// [P2PSessionService] send. Tests inject a mock or stub to verify that
/// the correct [BibCorrectionMessage] is produced without P2P machinery.
abstract class IBibCorrectionChannel {
  void sendCorrection(BibCorrectionMessage msg);
}
