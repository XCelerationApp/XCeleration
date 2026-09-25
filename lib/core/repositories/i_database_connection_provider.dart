import 'package:sqflite/sqflite.dart';

abstract interface class IDatabaseConnectionProvider {
  /// The open database for the signed-in user.
  ///
  /// Throws if no user's database is open. Only the coach side uses this; the
  /// timer and spectator keep their own databases and need no sign-in.
  Future<Database> get database;

  /// Opens (or creates) the database belonging to [userId], closing any other
  /// user's first. Called when a user signs in.
  Future<void> openForUser(String userId);

  Future<void> close();
  Future<void> deleteDatabase();

  /// Deletes [userId]'s database outright. Called when they delete their
  /// account, so their races do not sit on the phone afterwards.
  Future<void> deleteUserData(String userId);
}
