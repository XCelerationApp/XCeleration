/// Sent by the Bib Recorder when it deletes an entry, so the Verifier and
/// Fixer drop it from their queues instead of acting on a stale bib.
class BibEntryDeletedMessage {
  const BibEntryDeletedMessage({required this.entryId});

  /// The Bib Recorder's entry ID for the deleted bib.
  final int entryId;

  Map<String, dynamic> toJson() => {'entry_id': entryId};

  factory BibEntryDeletedMessage.fromJson(Map<String, dynamic> json) =>
      BibEntryDeletedMessage(entryId: json['entry_id'] as int);
}
