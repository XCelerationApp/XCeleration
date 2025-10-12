/// Model for storing bib records in the database
class BibRecord {
  final int raceId;
  final int bibId;
  final String bibNumber;
  final DateTime createdAt;

  const BibRecord({
    required this.raceId,
    required this.bibId,
    required this.bibNumber,
    required this.createdAt,
  });

  /// Creates a BibRecord from a database map
  factory BibRecord.fromMap(Map<String, dynamic> map) {
    return BibRecord(
      raceId: map['race_id'] as int,
      bibId: map['bib_id'] as int,
      bibNumber: map['bib_number'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  /// Converts a BibRecord to a database map
  Map<String, dynamic> toMap() {
    return {
      'race_id': raceId,
      'bib_id': bibId,
      'bib_number': bibNumber,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Creates a copy of this BibRecord with updated fields
  BibRecord copyWith({
    int? raceId,
    int? bibId,
    String? bibNumber,
    DateTime? createdAt,
  }) {
    return BibRecord(
      raceId: raceId ?? this.raceId,
      bibId: bibId ?? this.bibId,
      bibNumber: bibNumber ?? this.bibNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BibRecord &&
        other.raceId == raceId &&
        other.bibId == bibId &&
        other.bibNumber == bibNumber &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      raceId,
      bibId,
      bibNumber,
      createdAt,
    );
  }

  @override
  String toString() {
    return 'BibRecord(raceId: $raceId, bibId: $bibId, bibNumber: $bibNumber, createdAt: $createdAt)';
  }
}
