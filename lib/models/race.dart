
toRace(Map<String, dynamic> race) {
    return Race(
        raceId: race['race_id'],
        raceName: race['race_name'],
        raceDate: DateTime.parse(race['race_date']),
        location: race['location'],
        distance: race['distance'],
    );
}

class Race {
  final int raceId;
  final String raceName;
  final DateTime raceDate;
  final String location;
  final String distance;

  Race({
    required this.raceId,
    required this.raceName,
    required this.raceDate,
    required this.location,
    required this.distance,
  });

  // You can add getters if needed
  String get race_name => raceName;
  String get race_location => location;
  DateTime get race_date => raceDate;
  String get race_distance => distance;
  int get race_id => raceId;
}