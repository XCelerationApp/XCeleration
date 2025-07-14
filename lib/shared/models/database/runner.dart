/// Represents a runner in the racing application
class Runner {
  final int? runnerId;
  final String? name;
  final int? grade;
  final String? bibNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Runner({
    this.runnerId,
    this.name,
    this.grade,
    this.bibNumber,
    this.createdAt,
    this.updatedAt,
  });

  /// Create a Runner from a database map
  factory Runner.fromMap(Map<String, dynamic> map) {
    return Runner(
      runnerId: map['runner_id'],
      name: map['name'],
      bibNumber: map['bib_number'],
      grade: map['grade'],
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  /// Convert Runner to a map for database storage
  Map<String, dynamic> toMap({bool includeId = false, bool includeUpdatedAt = false}) {
    final map = {
      'name': name,
      'bib_number': bibNumber,
      'grade': grade,
    };

    if (includeId && runnerId != null) {
      map['runner_id'] = runnerId!;
    }
    if (includeUpdatedAt) {
      map['updated_at'] = DateTime.now().toIso8601String();
    }

    return map;
  }

  /// Create a copy of the runner with some fields replaced
  Runner copyWith({
    int? runnerId,
    String? name,
    int? grade,
    String? bibNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Runner(
      runnerId: runnerId ?? this.runnerId,
      name: name ?? this.name,
      grade: grade ?? this.grade,
      bibNumber: bibNumber ?? this.bibNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Runner(id: $runnerId, name: $name, bib: $bibNumber, grade: $grade)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Runner &&
        other.runnerId == runnerId &&
        other.name == name &&
        other.bibNumber == bibNumber &&
        other.grade == grade;
  }

  @override
  int get hashCode {
    return runnerId.hashCode ^
        name.hashCode ^
        bibNumber.hashCode ^
        grade.hashCode;
  }

  bool get isValid {
    return name != null &&
        name!.isNotEmpty &&
        bibNumber != null &&
        bibNumber!.isNotEmpty &&
        grade != null &&
        grade! >= 9 &&
        grade! <= 12;
  }
}
