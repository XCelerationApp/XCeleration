import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:xceleration/assistant/race_timer/model/timing_record.dart';
import '../../../shared/models/race.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert'; // Import jsonEncode

import '../coach/race_screen/widgets/runner_record.dart' show RunnerRecord;
import '../coach/race_screen/model/race_result.dart';
import '../coach/race_results/model/results_record.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    // await deleteDatabase();
    if (_database != null) return _database!;
    _database = await _initDB('races.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Create races table
    await db.execute('''
      CREATE TABLE races (
        race_id INTEGER PRIMARY KEY AUTOINCREMENT,
        race_name TEXT NOT NULL,
        race_date DATE,
        team_colors TEXT,
        teams TEXT,
        location TEXT,
        distance DOUBLE,
        distance_unit TEXT,
        flow_state TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create race runners table with updated structure
    await db.execute('''
      CREATE TABLE race_runners (
        runner_id INTEGER PRIMARY KEY AUTOINCREMENT,
        race_id INTEGER NOT NULL,
        bib_number TEXT NOT NULL,
        name TEXT NOT NULL,
        school TEXT,
        grade INTEGER,
        FOREIGN KEY (race_id) REFERENCES races(race_id),
        UNIQUE(race_id, bib_number)
      )
    ''');

    // Create race results table
    await db.execute('''
      CREATE TABLE race_results (
        result_id INTEGER PRIMARY KEY AUTOINCREMENT,
        race_id INTEGER NOT NULL,
        runner_id INTEGER NOT NULL,
        bib_number TEXT,
        place INTEGER,
        finish_time TEXT,
        name TEXT,
        school TEXT,
        grade INTEGER,
        FOREIGN KEY (race_id) REFERENCES races(race_id)
        FOREIGN KEY (runner_id) REFERENCES race_runners (runner_id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Add version 3 upgrade to rename the column
    if (oldVersion < 3) {
      try {
        // SQLite doesn't directly support column renaming in older versions
        // We need to create a new table with the correct structure and copy data
        
        // 1. Create a temporary table with the new structure
        await db.execute('''
          CREATE TABLE race_runners_new (
            runner_id INTEGER PRIMARY KEY AUTOINCREMENT,
            race_id INTEGER NOT NULL,
            bib_number TEXT NOT NULL,
            name TEXT NOT NULL,
            school TEXT,
            grade INTEGER,
            FOREIGN KEY (race_id) REFERENCES races(race_id),
            UNIQUE(race_id, bib_number)
          )
        ''');
        
        // 2. Copy data from the old table to the new one, mapping race_runner_id to runner_id
        await db.execute('''
          INSERT INTO race_runners_new (runner_id, race_id, bib_number, name, school, grade)
          SELECT race_runner_id, race_id, bib_number, name, school, grade FROM race_runners
        ''');
        
        // 3. Drop the old table
        await db.execute('DROP TABLE race_runners');
        
        // 4. Rename the new table to the original name
        await db.execute('ALTER TABLE race_runners_new RENAME TO race_runners');
        
        print('Successfully migrated race_runners table with renamed column');
      } catch (e) {
        print('Error during migration: $e');
      }
    }
  }

  // Team Runners Methods
  Future<int> insertTeamRunner(RunnerRecord runner) async {
    final db = await instance.database;
    return await db.insert('team_runners', runner.toMap(database: true));
  }

  // Update a team runner
  Future<int> updateTeamRunner(RunnerRecord runner) async {
    final db = await instance.database;
    return await db.update(
      'team_runners',
      runner.toMap(database: true),
      where: 'runner_id = ?',
      whereArgs: [runner.runnerId],
    );
  }


  Future<List<RunnerRecord>> getAllTeamRunners() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('team_runners');
    return List.generate(maps.length, (i) {
      return RunnerRecord.fromMap(maps[i]);
    });
  }

  Future<RunnerRecord?> getTeamRunnerByBib(String bib) async {
    final db = await instance.database;
    final results = await db.query(
      'team_runners',
      where: 'bib_number = ?',
      whereArgs: [bib],
    );
    return results.isNotEmpty ? RunnerRecord.fromMap(results.first) : null;
  }

  
  // Delete a team runner
  Future<int> deleteTeamRunner(String bib) async {
    final db = await instance.database;
    return await db.delete(
      'team_runners',
      where: 'bib_number = ?',
      whereArgs: [bib],
    );
  }


  // Races Methods
  Future<int> insertRace(Race race) async {
    final db = await instance.database;
    return await db.insert('races', race.toMap(database: true));
  }
  
  Future<int> updateRace(Race race) async {
    final db = await instance.database;
    return await db.update(
      'races',
      race.toMap(database: true),
      where: 'race_id = ?',
      whereArgs: [race.raceId],
    );
  }

  Future<List<Race>> getAllRaces() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'races',
      orderBy: 'race_date DESC',
    );

    List<Race> result = [];
    
    for (var map in maps) {
      result.add(Race.fromJson(map));
    }

    return result;
  }

  Future<Race?> getRaceById(int id) async {
    final db = await instance.database;
    final results = await db.query(
      'races',
      where: 'race_id = ?',
      whereArgs: [id],
    );
    
    if (results.isEmpty) return null;
    
    return Race.fromJson(results.first);
  }

  // Race Runners Methods
  Future<int> insertRaceRunner(RunnerRecord runner) async {
    final db = await instance.database;
    return await db.insert(
      'race_runners',
      runner.toMap(database: true),
      conflictAlgorithm: ConflictAlgorithm.replace, // Replace if bib number exists in race
    );
  }

  Future<List<RunnerRecord>> getRaceRunners(int raceId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'race_runners',
      where: 'race_id = ?',
      whereArgs: [raceId],
      orderBy: 'bib_number',
    );
    return maps.map((map) => RunnerRecord.fromMap(map)).toList();
  }

  Future<RunnerRecord?> getRaceRunnerByBib(int raceId, String bibNumber) async {
    final db = await instance.database;
    final results = await db.query(
      'race_runners',
      where: 'race_id = ? AND bib_number = ?',
      whereArgs: [raceId, bibNumber],
    );

    final Map<String, dynamic>? runner = results.isNotEmpty ? results.first : null;
    return runner == null ? null : RunnerRecord.fromMap(runner);
  }

  Future<List<RunnerRecord>> getRaceRunnersByBibs(int raceId, List<String> bibNumbers) async {
    List<RunnerRecord> results = [];
    for (int i = 0; i < bibNumbers.length; i++) {
      final runner = await getRaceRunnerByBib(raceId, bibNumbers[i]);
      if (runner == null) {
        break;
      }
      results.add(runner);
    }
    return results;
  }


  Future<void> updateRaceRunner(RunnerRecord runner) async {
    final db = await instance.database;
    await db.update(
      'race_runners',
      runner.toMap(database: true),
      where: 'runner_id = ?',
      whereArgs: [runner.runnerId],
    );
  }

  Future<void> deleteRaceRunner(int raceId, String bibNumber) async {
    final db = await instance.database;
    await db.delete(
      'race_runners',
      where: 'race_id = ? AND bib_number = ?',
      whereArgs: [raceId, bibNumber],
    );
  }

  Future<List<RunnerRecord>> searchRaceRunners(int raceId, String query, [String searchParameter = 'all']) async {
    final db = await instance.database;
    String whereClause;
    List<dynamic> whereArgs = [raceId, '%$query%'];
    if (searchParameter == 'all') {
      whereClause = 'race_id = ? AND (name LIKE ? OR grade LIKE ? OR bib_number LIKE ?)';
      whereArgs.add('%$query%');
      whereArgs.add('%$query%');
    } else {
      whereClause = 'race_id = ? AND $searchParameter LIKE ?';
    }
    final results = await db.query(
      'race_runners',
      where: whereClause,
      whereArgs: whereArgs,
    );
    return results.map((map) => RunnerRecord.fromMap(map)).toList();
  }

  Future<void> insertRaceResults(List<RaceResult> results) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var result in results) {
      batch.insert('race_results', result.toMap(database: true));
    }
    await batch.commit();
    return;
  }

  Future<List<ResultsRecord>> getRaceResults(int raceId) async {
    final db = await instance.database;
    late final List<Map<String, dynamic>>? rawResults;
    
    try {
      // Simplified query to directly get results from race_results table
      rawResults = await db.rawQuery('''
        SELECT 
          runner_id, 
          bib_number, 
          name, 
          school, 
          grade, 
          place, 
          finish_time
        FROM race_results
        WHERE race_id = ?
      ''', [raceId]); 
    } catch (e) {
      print('Query error: $e');
    }
    if (rawResults != null && rawResults.isNotEmpty) {
      final results = rawResults.map((r) => ResultsRecord.fromMap(r)).toList();
      results.sort((a, b) => a.finishTime.compareTo(b.finishTime));
      return results;
    }
    // Fallback to test data if query fails or for other race IDs
    debugPrint('Query failed or no results found for race ID $raceId');
    List<ResultsRecord> results = [];
    for (int i = 0; i < 20; i++) {
      results.add(
        ResultsRecord(
          bib: '${1001 + i}',
          name: 'John Doe',
          school: ['AW', 'TL', 'SR'][i % 3],
          grade: 9,
          place: i + 1,
          finishTime: Duration(seconds: 5 + i),
          raceId: raceId,
          runnerId: 1000 + i, // Using a predictable ID based on index
        ),
      );
    }
    return results;
  }

  Future<List<TimingRecord>> getAllResults() async {
    final db = await instance.database;
    final results = await db.query('race_results');
    return results.map((r) => TimingRecord.fromMap(r, database: true)).toList();
  }



  Future<String> getRaceState(int raceId, {race}) async {
    final raceResults = await instance.getRaceResults(raceId);
    if (raceResults.isEmpty) return 'in_progress';
    return 'finished';
  }

  Future<void> updateRaceFlowState(int raceId, String flowState) async {
    final db = await instance.database;
    await db.update(
      'races',
      {'flow_state': flowState},
      where: 'race_id = ?',
      whereArgs: [raceId],
    );
  }

  // Save race results
  Future<void> saveRaceResults(int raceId, List<ResultsRecord> resultRecords) async {
    final db = await instance.database;

    try {
      // First, delete existing results for this race
      await db.delete(
        'race_results',
        where: 'race_id = ?',
        whereArgs: [raceId],
      );
      
      // Then insert all the new results
      final batch = db.batch();
      for (final result in resultRecords) {
        batch.insert('race_results', result.toMap());
      }
      await batch.commit();
      
      print('Successfully saved ${resultRecords.length} race results for race $raceId');
    } catch (e) {
      print('Error saving race results: $e');
      rethrow;
    }
  }

  Future<List<ResultsRecord>?> getRaceResultsData(int raceId) async {
    final db = await instance.database;
    
    final results = await db.query(
      'race_results',
      where: 'race_id = ?',
      whereArgs: [raceId],
    );
    
    if (results.isEmpty) return null;
    
    return results.map((r) => ResultsRecord.fromMap(r)).toList();
  }

  // Update individual fields of a race
  Future<void> updateRaceField(int raceId, String field, dynamic value) async {
    final db = await instance.database;
    
    // Convert field name to database column name format
    final String dbField = field.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}'
    );
    
    // Special handling for list fields
    if (field == 'teams' || field == 'teamColors') {
      // Get current race data
      final race = await getRaceById(raceId);
      if (race == null) return;
      
      // Update the race with the new field value
      Map<String, dynamic> raceMap = race.toMap(database: true);
      
      if (field == 'teams') {
        // Ensure teams is properly encoded as JSON string
        raceMap['teams'] = jsonEncode(value);
      } else if (field == 'teamColors') {
        // Ensure teamColors is properly encoded as JSON string
        raceMap['team_colors'] = jsonEncode(value);
      }
      
      // Update the entire race
      await db.update(
        'races',
        raceMap,
        where: 'race_id = ?',
        whereArgs: [raceId],
      );
    } else {
      // For non-list fields, update just the specific field
      await db.update(
        'races',
        {dbField: value},
        where: 'race_id = ?',
        whereArgs: [raceId],
      );
    }
    
  }

  Future<void> deleteRace(int raceId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Delete related records first
      await txn.delete('race_results', where: 'race_id = ?', whereArgs: [raceId]);
      await txn.delete('race_runners', where: 'race_id = ?', whereArgs: [raceId]);
      await txn.delete('races', where: 'race_id = ?', whereArgs: [raceId]);
    });
  }

  Future<void> deleteAllRaces() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('race_results');
      await txn.delete('race_runners');
      await txn.delete('races');
    });
  }

  Future<void> deleteAllRaceRunners(int raceId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Delete related race results first (due to foreign key constraint)
      await txn.delete('race_results', where: 'race_id = ?', whereArgs: [raceId]);
      // Then delete all runners for this race
      await txn.delete('race_runners', where: 'race_id = ?', whereArgs: [raceId]);
    });
  }
  
  Future<void> clearTeamRunners() async {
    final db = await instance.database;
    await db.rawUpdate('UPDATE team_runners SET name = \'\', school = \'\', grade = 0, bib_number = 0');
  }


  Future<void> deleteDatabase() async {
    debugPrint('deleting database');
    String path = join(await getDatabasesPath(), 'races.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
}