import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/core/repositories/database_connection_provider.dart';
import 'package:xceleration/core/utils/local_schema.dart';

import 'fixtures/local_schema_v17.dart';

/// Opens a real v17 database (as shipped before XCE-230) through the current
/// [DatabaseConnectionProvider], exercising its actual onUpgrade path.
void main() {
  late String path;
  late DatabaseConnectionProvider provider;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    path = join(await getDatabasesPath(), 'races.db');
    await databaseFactory.deleteDatabase(path);

    final v17 = await openDatabase(path, version: 17, onCreate: (db, _) async {
      for (final statement in splitSqlStatements(localSchemaV17Sql)) {
        await db.execute(statement);
      }
    });
    await v17.insert('races', {'race_id': 1, 'name': 'Meet'});
    await v17.insert('teams', {'team_id': 1, 'name': 'Lincoln'});
    await v17.insert('runners', {'runner_id': 1, 'name': 'Ann', 'bib_number': '101'});
    await v17.insert('runners', {'runner_id': 2, 'name': 'Bob', 'bib_number': '102'});
    await v17.insert('race_participants', {'race_id': 1, 'runner_id': 1, 'team_id': 1});
    await v17.insert('race_participants', {'race_id': 1, 'runner_id': 2, 'team_id': 1});
    await v17.close();

    provider = DatabaseConnectionProvider();
  });

  tearDown(() async {
    await provider.close();
    await databaseFactory.deleteDatabase(path);
  });

  group('DatabaseConnectionProvider upgrade from v17', () {
    test('adds a uuid column to race_participants', () async {
      final db = await provider.database;

      final columns = (await db.rawQuery('PRAGMA table_info(race_participants)'))
          .map((c) => c['name'])
          .toList();

      expect(columns, contains('uuid'));
    });

    test('keeps existing race_participants rows', () async {
      final db = await provider.database;

      expect(await db.query('race_participants'), hasLength(2));
    });

    test('rejects two race_participants with the same uuid', () async {
      final db = await provider.database;
      await db.update('race_participants', {'uuid': 'same'},
          where: 'runner_id = ?', whereArgs: [1]);

      expect(
        () => db.update('race_participants', {'uuid': 'same'},
            where: 'runner_id = ?', whereArgs: [2]),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
