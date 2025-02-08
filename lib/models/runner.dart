class Runner {
  final String name;
  final String bibNumber;
  final int raceId;
  final String grade;
  final String school;
  
  Runner({
    required this.name,
    required this.bibNumber,
    required this.raceId,
    required this.grade,
    required this.school,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'bib_number': bibNumber,
      'race_id': raceId,
      'grade': grade,
      'school': school,
    };
  }

  factory Runner.fromMap(Map<String, dynamic> map) {
    return Runner(
      name: map['name'],
      bibNumber: map['bib_number'],
      raceId: map['race_id'],
      grade: map['grade'],
      school: map['school'],
    );
  }
}
