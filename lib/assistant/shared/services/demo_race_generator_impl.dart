import '../models/race_record.dart';
import 'demo_race_generator.dart';
import 'i_demo_race_generator.dart';

/// Concrete implementation of [IDemoRaceGenerator] that delegates to the
/// [DemoRaceGenerator] static helpers.
class DemoRaceGeneratorImpl implements IDemoRaceGenerator {
  const DemoRaceGeneratorImpl();

  @override
  Future<bool> ensureDemoRaceExists(String deviceType) =>
      DemoRaceGenerator.ensureDemoRaceExists(deviceType);

  @override
  bool isDemoRace(RaceRecord race) => DemoRaceGenerator.isDemoRace(race);
}
