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
///
/// Runner context fields ([runnerName], [teamAbbreviation], [teamColor]) are
/// optional: the Recorder resolves them via its local roster at send time.
/// A null value means the bib was unmatched (unknown runner).
class BibEntryMessage {
  const BibEntryMessage({
    required this.finishPosition,
    required this.bib,
    required this.status,
    required this.timestamp,
    this.runnerName,
    this.teamAbbreviation,
    this.teamColor,
  });

  final int finishPosition;
  final int bib;
  final BibEntryStatus status;
  final DateTime timestamp;

  /// Runner's display name, or null if bib is unmatched.
  final String? runnerName;

  /// Team abbreviation (e.g. "NCC"), or null if unmatched.
  final String? teamAbbreviation;

  /// Team colour encoded as a 32-bit ARGB int (same as [Color.toARGB32]),
  /// or null if unmatched.
  final int? teamColor;

  Map<String, dynamic> toJson() => {
        'finish_position': finishPosition,
        'bib': bib,
        'status': status.wireValue,
        'timestamp': timestamp.toUtc().toIso8601String(),
        if (runnerName != null) 'runner_name': runnerName,
        if (teamAbbreviation != null) 'team_abbreviation': teamAbbreviation,
        if (teamColor != null) 'team_color': teamColor,
      };

  factory BibEntryMessage.fromJson(Map<String, dynamic> json) =>
      BibEntryMessage(
        finishPosition: json['finish_position'] as int,
        bib: json['bib'] as int,
        status: BibEntryStatus.fromWireValue(json['status'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
        runnerName: json['runner_name'] as String?,
        teamAbbreviation: json['team_abbreviation'] as String?,
        teamColor: json['team_color'] as int?,
      );
}
