/// Represents a bib number record with validation flags
class BibRecord {
  final String bibNumber;
  final List<double> confidences;
  final String name;
  final String school;
  final Map<String, bool> flags;
  final DateTime? timestamp;
  final bool isValidated;

  BibRecord({
    this.bibNumber = '',
    this.confidences = const [],
    this.name = '',
    this.school = '',
    this.timestamp,
    this.isValidated = false,
  }) : flags = {
          'duplicate_bib_number': false,
          'not_in_database': false,
          'low_confidence_score': false,
        };

  /// Create a copy with updated fields
  BibRecord copyWith({
    String? bibNumber,
    List<double>? confidences,
    String? name,
    String? school,
    Map<String, bool>? flags,
    DateTime? timestamp,
    bool? isValidated,
  }) {
    return BibRecord(
      bibNumber: bibNumber ?? this.bibNumber,
      confidences: confidences ?? this.confidences,
      name: name ?? this.name,
      school: school ?? this.school,
      timestamp: timestamp ?? this.timestamp,
      isValidated: isValidated ?? this.isValidated,
    );
  }

  /// Check if the record has any validation errors
  bool get hasErrors => flags.values.any((flag) => flag);

  /// Check if the record is valid and complete
  bool get isValid => !hasErrors && bibNumber.isNotEmpty && isValidated;

  /// Get the highest confidence score
  double get maxConfidence => confidences.isNotEmpty
      ? confidences.reduce((a, b) => a > b ? a : b)
      : 0.0;

  /// Get the average confidence score
  double get averageConfidence => confidences.isNotEmpty
      ? confidences.reduce((a, b) => a + b) / confidences.length
      : 0.0;

  /// Convert to JSON for storage/transmission
  Map<String, dynamic> toJson() {
    return {
      'bib_number': bibNumber,
      'confidences': confidences,
      'name': name,
      'school': school,
      'flags': flags,
      'timestamp': timestamp?.toIso8601String(),
      'is_validated': isValidated,
    };
  }

  /// Create from JSON
  factory BibRecord.fromJson(Map<String, dynamic> json) {
    return BibRecord(
      bibNumber: json['bib_number'] ?? '',
      confidences: List<double>.from(json['confidences'] ?? []),
      name: json['name'] ?? '',
      school: json['school'] ?? '',
      timestamp:
          json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
      isValidated: json['is_validated'] ?? false,
    );
  }

  /// Get a summary of validation issues
  List<String> get validationIssues {
    final issues = <String>[];
    if (flags['duplicate_bib_number'] == true) {
      issues.add('Duplicate bib number detected');
    }
    if (flags['not_in_database'] == true) {
      issues.add('Runner not found in database');
    }
    if (flags['low_confidence_score'] == true) {
      issues.add('Low confidence in bib number recognition');
    }
    if (bibNumber.isEmpty) {
      issues.add('Bib number is required');
    }
    return issues;
  }

  @override
  String toString() {
    return 'BibRecord(bib: $bibNumber, name: $name, school: $school, valid: $isValid)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BibRecord &&
        other.bibNumber == bibNumber &&
        other.name == name &&
        other.school == school;
  }

  @override
  int get hashCode {
    return Object.hash(bibNumber, name, school);
  }
}
