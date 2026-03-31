import 'package:sqflite/sqflite.dart';

abstract interface class IDatabaseConnectionProvider {
  Future<Database> get database;
  Future<void> openForUser(String userId);
  Future<void> close();
  Future<void> deleteDatabase();
  Future<void> deleteUserData(String userId);
}
