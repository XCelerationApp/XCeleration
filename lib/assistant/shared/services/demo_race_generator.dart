import 'package:flutter/material.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/logger.dart';
import '../models/race_record.dart';
import '../models/runner.dart';
import 'assistant_storage_service.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';

/// Service to generate and load a demo race for assistants to practice with
class DemoRaceGenerator {
  static const int _demoRaceId = -1; // Demo race ID
  static const String _demoRaceName = 'Demo Race';

  /// Creates a demo race if no races exist for the given device type.
  static Future<bool> ensureDemoRaceExists(String deviceType) async {
    try {
      final storage = AssistantStorageService.instance;

      final racesResult = await storage.getRaces(deviceType);
      final races = switch (racesResult) {
        Success(:final value) => value,
        Failure() => <RaceRecord>[],
      };

      if (races.isNotEmpty) {
        return false;
      }

      await _createDemoRace(deviceType);

      Logger.d('Demo race created for $deviceType');
      return true;
    } catch (e) {
      Logger.e('Failed to ensure demo race exists: $e');
      return false;
    }
  }

  /// Creates a demo race with sample runners
  static Future<void> _createDemoRace(String deviceType) async {
    final storage = AssistantStorageService.instance;

    // Create the race record
    final raceRecord = RaceRecord(
      raceId: _demoRaceId,
      date: DateTime.now(),
      name: _demoRaceName,
      type: deviceType,
      stopped: true, // Start in stopped state
    );

    // Save the race
    await storage.saveNewRace(raceRecord);

    // Create sample runners
    final runners = _generateSampleRunners();

    // Save runners to database
    await storage.saveRunners(_demoRaceId, runners);

    // For timing screen, create an initial empty chunk
    if (deviceType.contains('timer') || deviceType.contains('Timer')) {
      await storage.saveChunk(
        _demoRaceId,
        TimingChunk(id: 0, timingData: []),
      );
    }
  }

  /// Generates a list of sample runners with realistic data
  static List<Runner> _generateSampleRunners() {
    final now = DateTime.now();

    // Define some sample teams with colors
    final teams = [
      {
        'abbr': 'EAG',
        'name': 'Eagles',
        'color': const Color(0xFF1976D2)
      }, // Blue
      {
        'abbr': 'TIG',
        'name': 'Tigers',
        'color': const Color(0xFFFF6F00)
      }, // Orange
      {
        'abbr': 'FAL',
        'name': 'Falcons',
        'color': const Color(0xFF388E3C)
      }, // Green
      {'abbr': 'LIO', 'name': 'Lions', 'color': const Color(0xFFD32F2F)}, // Red
    ];

    final firstNames = [
      'Alex',
      'Jordan',
      'Casey',
      'Morgan',
      'Taylor',
      'Riley',
      'Avery',
      'Quinn',
      'Parker',
      'Cameron',
      'Skyler',
      'River',
      'Sage',
      'Rowan',
      'Logan'
    ];

    final lastNames = [
      'Johnson',
      'Smith',
      'Williams',
      'Brown',
      'Davis',
      'Miller',
      'Wilson',
      'Moore',
      'Taylor',
      'Anderson',
      'Thomas',
      'Jackson',
      'White',
      'Harris',
      'Martin'
    ];

    final grades = ['9', '10', '11', '12'];

    final runners = <Runner>[];

    // Create 15 sample runners
    for (int i = 0; i < 15; i++) {
      final team = teams[i % teams.length];
      final firstName = firstNames[i % firstNames.length];
      final lastName = lastNames[(i * 3) % lastNames.length];
      final grade = grades[i % grades.length];

      runners.add(Runner(
        raceId: _demoRaceId,
        bibNumber: (i + 1).toString(), // Bib numbers 1-15
        name: '$firstName $lastName',
        teamAbbreviation: team['abbr'] as String,
        grade: grade,
        teamColor: team['color'] as Color,
        createdAt: now,
      ));
    }

    return runners;
  }

  /// Checks if a race is the demo race
  static bool isDemoRace(RaceRecord race) {
    return race.raceId == _demoRaceId || race.name.contains('Demo Race');
  }

  /// Deletes the demo race if it exists
  static Future<void> deleteDemoRace(String deviceType) async {
    try {
      final storage = AssistantStorageService.instance;
      final raceResult = await storage.getRace(_demoRaceId, deviceType);
      final race = switch (raceResult) {
        Success(:final value) => value,
        Failure() => null,
      };

      if (race != null) {
        await storage.deleteRace(_demoRaceId, deviceType);
        Logger.d('Demo race deleted for $deviceType');
      }
    } catch (e) {
      Logger.e('Failed to delete demo race: $e');
    }
  }

}
