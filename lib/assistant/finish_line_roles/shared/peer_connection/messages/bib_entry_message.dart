/// Status of a bib recording as determined by the Bib Recorder's roster check.
enum BibEntryStatus {
  resolved,
  unknown,
  duplicate;

  String get wireValue => name;

  static BibEntryStatus fromWireValue(String value) =>
      BibEntryStatus.values.byName(value);
}

/// A single bib recording sent from BibRecorderV2 → Verifier.
class BibEntryMessage {
  const BibEntryMessage({
    required this.finishPosition,
    required this.bib,
    required this.status,
    required this.timestamp,
  });

  final int finishPosition;
  final int bib;
  final BibEntryStatus status;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'finish_position': finishPosition,
        'bib': bib,
        'status': status.wireValue,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };

  factory BibEntryMessage.fromJson(Map<String, dynamic> json) =>
      BibEntryMessage(
        finishPosition: json['finish_position'] as int,
        bib: json['bib'] as int,
        status: BibEntryStatus.fromWireValue(json['status'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
