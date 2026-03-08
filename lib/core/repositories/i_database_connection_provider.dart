import 'package:sqflite/sqflite.dart';

abstract class IDatabaseConnectionProvider {
  Future<Database> get database;
  Future<void> close();
  Future<void> deleteDatabase();
}
