import '../models/race_record.dart';

abstract interface class IDemoRaceGenerator {
  Future<bool> ensureDemoRaceExists(String deviceType);

  bool isDemoRace(RaceRecord race);
}
