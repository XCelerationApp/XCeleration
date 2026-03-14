import 'package:sqflite/sqflite.dart';

abstract interface class IDatabaseConnectionProvider {
  Future<Database> get database;
  Future<void> close();
  Future<void> deleteDatabase();
}
