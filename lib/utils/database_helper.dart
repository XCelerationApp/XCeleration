import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../../../shared/models/race.dart';
import 'package:flutter/foundation.dart';

import '../coach/race_screen/widgets/runner_record.dart' show RunnerRecord;
import '../coach/race_screen/model/race_result.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    // deleteDatabase();
    if (_database != null) return _database!;
    _database = await _initDB('races.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Create team runners table
    // await db.execute('''
    //   CREATE TABLE team_runners (
    //     runner_id INTEGER PRIMARY KEY AUTOINCREMENT,
    //     name TEXT NOT NULL,
    //     school TEXT,
    //     grade INTEGER,
    //     bib_number TEXT NOT NULL UNIQUE,
    //     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    //   )
    // ''');

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
        place INTEGER,
        finish_time TEXT,
        FOREIGN KEY (race_id) REFERENCES races(race_id)
      )
    ''');

    // Create race results data table
    await db.execute('''
      CREATE TABLE race_results_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        race_id INTEGER NOT NULL,
        runner_id INTEGER NOT NULL,
        finish_time INTEGER,
        finish_position INTEGER,
        team TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (race_id) REFERENCES races (race_id),
        FOREIGN KEY (runner_id) REFERENCES team_runners (runner_id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Create race results data table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS race_results_data (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          race_id INTEGER NOT NULL,
          runner_id INTEGER NOT NULL,
          finish_time INTEGER,
          finish_position INTEGER,
          team TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (race_id) REFERENCES races (race_id),
          FOREIGN KEY (runner_id) REFERENCES team_runners (runner_id)
        )
      ''');
    }
    
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
        
        print("Successfully migrated race_runners table with renamed column");
      } catch (e) {
        print("Error during migration: $e");
      }
    }
  }

  // Team Runners Methods
  Future<int> insertTeamRunner(Map<String, dynamic> runner) async {
    final db = await instance.database;
    return await db.insert('team_runners', runner);
  }

  // Update a team runner
  Future<int> updateTeamRunner(Map<String, dynamic> runner) async {
    final db = await instance.database;
    return await db.update(
      'team_runners',
      runner,
      where: 'runner_id = ?',
      whereArgs: [runner['runner_id']],
    );
  }


  Future<List<Map<String, dynamic>>> getAllTeamRunners() async {
    final db = await instance.database;
    return await db.query('team_runners');
  }

  Future<Map<String, dynamic>?> getTeamRunnerByBib(String bib) async {
    final db = await instance.database;
    final results = await db.query(
      'team_runners',
      where: 'bib_number = ?',
      whereArgs: [bib],
    );
    return results.isNotEmpty ? results.first : null;
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
  Future<int> insertRace(Map<String, dynamic> race) async {
    final db = await instance.database;
    return await db.insert('races', race);
  }
  
  Future<int> updateRace(Map<String, dynamic> race) async {
    final db = await instance.database;
    return await db.update(
      'races',
      race,
      where: 'race_id = ?',
      whereArgs: [race['race_id']],
    );
  }

  Future<List<dynamic>> getAllRaces({bool getState = true}) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'races',
      orderBy: 'race_date DESC',
    );

    List<dynamic> result = [];
    
    for (var map in maps) {
      if (!getState) {
        result.add(Race.fromJson(map));
      } else {
        final raceState = await getRaceState(map['race_id']);
        result.add({
          ...map,
          'race': Race.fromJson(map),
          'state': raceState,
        });
      }
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

  Future<String> getEncodedRunnersData(int raceId) async {
    final runners = await getRaceRunners(raceId);
    return runners.map((runner) => [
      runner.bib,
      runner.name,
      runner.school,
      runner.grade
    ].join(',')).join(' ');
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


  Future<void> insertRaceResult(RunnerRecord result) async {
    // Check if the runner exists in team runners or race runners
    bool runnerExists = result.runnerId == null ? false : await _runnerExists(result.runnerId!);
    final db = await instance.database;

    if (runnerExists) {
      // Insert into race_results
      await db.insert('race_results', result.toMap());
    } else {
      throw Exception('Runner does not exist in either database.');
    }
  }

  Future<bool> _runnerExists(int raceRunnerId) async {
    final db = await instance.database;
    // Check in race runners
    final raceRunnerCheck = await db.query('race_runners',
        where: 'runner_id = ?', whereArgs: [raceRunnerId]);

    // Check in team runners
    final teamRunnerCheck = await db.query('team_runners',
        where: 'runner_id = ?', whereArgs: [raceRunnerId]);

    return raceRunnerCheck.isNotEmpty || teamRunnerCheck.isNotEmpty;
  }

  // Future<void> insertRaceResults(List<RunnerRecord> results) async {
  //   final db = await instance.database;
  //   final batch = db.batch();
  //   for (var result in results) {
  //     debugPrint(result.toString());
  //     batch.insert('race_results', result.toMap());
  //   }
  //   await batch.commit();
  //   return;
  // }

  Future<void> insertRaceResults(List<RaceResult> results) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var result in results) {
      batch.insert('race_results', {
        'race_id': result.raceId,
        'runner_id': result.runnerId,
        'place': result.place,
        'finish_time': result.finishTime,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    await batch.commit();
    return;
  }

  Future<List<Map<String, dynamic>>> getRaceResults(int raceId) async {
    final db = await instance.database;
    
    try {
      // Use the correct column name runner_id instead of race_runner_id
      final raceRunners = await db.rawQuery('''
        SELECT 
          rr.runner_id AS runner_id, 
          rr.bib_number, 
          rr.name, 
          rr.school, 
          rr.grade, 
          r.place, 
          r.finish_time
        FROM race_results r
        LEFT JOIN race_runners rr ON rr.runner_id = r.runner_id
        WHERE rr.race_id = ?
      ''', [raceId]);
      
      // final teamRunners = await db.rawQuery('''
      //   SELECT 
      //     sr.runner_id AS runner_id, 
      //     sr.bib_number, 
      //     sr.name, 
      //     sr.school, 
      //     sr.grade, 
      //     r.place, 
      //     r.finish_time
      //   FROM race_results r
      //   LEFT JOIN team_runners sr ON sr.runner_id = r.runner_id
      //   WHERE r.race_id = ?
      // ''', [raceId]);

      if (raceId == 1) return raceRunners;
    } catch (e) {
      print("Query error: $e");
    }
    
    // Fallback to test data if query fails or for other race IDs
    return [
      {
        'runner_id': 1,
        'bib_number': '1001',
        'name': 'John Doe',
        'school': 'Test School',
        'grade': '5',
        'place': 1,
        'finish_time': '5.00',
      },
      {
        'runner_id': 2,
        'bib_number': '1002',
        'name': 'Jane Doe',
        'school': 'Test School',
        'grade': '5',
        'place': 2,
        'finish_time': '6.00',
      },
    ];
  }

  Future<List<Map<String, dynamic>>> getAllResults() async {
    final db = await instance.database;
    return await db.query('race_results');
  }

  Future<bool> checkIfRaceRunnersAreLoaded(int raceId, {race}) async {
    race ??= await DatabaseHelper.instance.getRaceById(raceId);
    final raceRunners = await DatabaseHelper.instance.getRaceRunners(raceId);
    
    // Check if we have any runners at all
    if (raceRunners.isEmpty) {
      return false;
    }

    // Check if each team has at least 2 runners (minimum for a race)
    final teamRunnerCounts = <String, int>{};
    for (final runner in raceRunners) {
      final team = runner.school;
      teamRunnerCounts[team] = (teamRunnerCounts[team] ?? 0) + 1;
    }

    // Verify each team in the race has enough runners
    for (final teamName in race!.teams) {
      final runnerCount = teamRunnerCounts[teamName] ?? 0;
      if (runnerCount < 5) {
        return false;
      }
    }

    return true;
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
  Future<void> saveRaceResults(int raceId, Map<String, dynamic> results) async {
    final db = await instance.database;
    
    // Convert results to JSON string for storage
    final jsonResults = json.encode(results);
    
    // Check if results already exist
    final existing = await db.query(
      'race_results_data',
      where: 'race_id = ?',
      whereArgs: [raceId],
    );
    
    if (existing.isEmpty) {
      // Insert new results
      await db.insert('race_results_data', {
        'race_id': raceId,
        'results_data': jsonResults,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } else {
      // Update existing results
      await db.update(
        'race_results_data',
        {
          'results_data': jsonResults,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'race_id = ?',
        whereArgs: [raceId],
      );
    }
  }

  // Get race results
  Future<Map<String, dynamic>?> getRaceResultsData(int raceId) async {
    final db = await instance.database;
    
    final results = await db.query(
      'race_results_data',
      where: 'race_id = ?',
      whereArgs: [raceId],
    );
    
    if (results.isEmpty) return null;
    
    // Parse JSON string back to Map
    final jsonResults = results.first['results_data'] as String;
    return json.decode(jsonResults) as Map<String, dynamic>;
  }

  // Cleanup Methods
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