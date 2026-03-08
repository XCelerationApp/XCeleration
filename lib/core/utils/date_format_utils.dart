/// Shared date formatting utilities used across the app.
abstract final class DateFormatUtils {
  /// Returns a human-readable label for [date] relative to today.
  ///
  /// - Same day → `'Today'`
  /// - Next day → `'Tomorrow'`
  /// - Previous day → `'Yesterday'`
  /// - Within the next 7 days → `'In N days'`
  /// - Within the past 7 days → `'N days ago'`
  /// - Otherwise → `'M/D/YYYY'`
  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    // Use UTC midnight to avoid DST hour shifts affecting inDays.
    final today = DateTime.utc(now.year, now.month, now.day);
    final dateDay = DateTime.utc(date.year, date.month, date.day);
    final difference = dateDay.difference(today).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference == -1) return 'Yesterday';
    if (difference > 0 && difference <= 7) return 'In $difference days';
    if (difference < 0 && difference >= -7) return '${-difference} days ago';

    return '${date.month}/${date.day}/${date.year}';
  }
}
