/// Represents a runner in the racing application
class Runner {
  final int? runnerId;
  final String? uuid;
  final String? name;
  final int? grade;
  final String? bibNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int? isDirty;

  const Runner({
    this.runnerId,
    this.uuid,
    this.name,
    this.grade,
    this.bibNumber,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.isDirty,
  });

  /// Create a Runner from a database map
  factory Runner.fromMap(Map<String, dynamic> map) {
    return Runner(
      runnerId: map['runner_id'],
      uuid: map['uuid'],
      name: map['name'],
      bibNumber: map['bib_number'],
      grade: map['grade'],
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      deletedAt:
          map['deleted_at'] != null ? DateTime.parse(map['deleted_at']) : null,
      isDirty: map['is_dirty'],
    );
  }

  /// Convert Runner to a map for database storage
  Map<String, dynamic> toMap() {
    final map = {
      'name': name,
      'bib_number': bibNumber,
      'grade': grade,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'is_dirty': isDirty,
    };

    return map;
  }

  /// Create a copy of the runner with some fields replaced
  Runner copyWith({
    int? runnerId,
    String? uuid,
    String? name,
    int? grade,
    String? bibNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? isDirty,
  }) {
    return Runner(
      runnerId: runnerId ?? this.runnerId,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      grade: grade ?? this.grade,
      bibNumber: bibNumber ?? this.bibNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  @override
  String toString() {
    return 'Runner(id: $runnerId, uuid: $uuid, name: $name, bib: $bibNumber, grade: $grade)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Runner &&
        other.runnerId == runnerId &&
        other.uuid == uuid &&
        other.name == name &&
        other.bibNumber == bibNumber &&
        other.grade == grade &&
        other.deletedAt == deletedAt &&
        other.isDirty == isDirty &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return runnerId.hashCode ^
        uuid.hashCode ^
        name.hashCode ^
        bibNumber.hashCode ^
        grade.hashCode ^
        (createdAt?.hashCode ?? 0) ^
        (updatedAt?.hashCode ?? 0) ^
        (deletedAt?.hashCode ?? 0) ^
        (isDirty ?? 0).hashCode;
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
