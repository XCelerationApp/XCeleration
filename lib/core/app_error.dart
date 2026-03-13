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
