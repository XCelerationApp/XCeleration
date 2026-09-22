final class AppError {
  const AppError({
    required this.userMessage,
    this.originalException,
  });

  /// Safe to display in the UI.
  final String userMessage;

  /// For logging only — never show to the user.
  final Object? originalException;
}

/// Thrown when deleting something would also delete saved data that depends
/// on it, such as a runner or team with race results (the database cascades
/// those deletes). [message] is safe to show to the user.
final class DataInUseException implements Exception {
  const DataInUseException(this.message);

  final String message;

  @override
  String toString() => 'DataInUseException: $message';
}
