import 'package:intl/intl.dart';

/// Formats a date string into a readable format
/// Input format expected: 'YYYY-MM-DD' or ISO 8601 format
String formatDate(String dateStr) {
  try {
    final DateTime date = DateTime.parse(dateStr);
    return DateFormat('MMM dd, yyyy').format(date);
  } catch (e) {
    print('Error formatting date: $e');
    return dateStr; // Return original string if parsing fails
  }
}

/// Formats a date string into a short format
/// Output format: 'MM/DD/YY'
String formatShortDate(String dateStr) {
  try {
    final DateTime date = DateTime.parse(dateStr);
    return DateFormat('MM/dd/yy').format(date);
  } catch (e) {
    print('Error formatting short date: $e');
    return dateStr;
  }
}

/// Returns a readable relative date (Today, Yesterday, etc.)
String getRelativeDate(String dateStr) {
  try {
    final DateTime date = DateTime.parse(dateStr);
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return 'Today';
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday';
    } else {
      return formatDate(dateStr);
    }
  } catch (e) {
    print('Error getting relative date: $e');
    return dateStr;
  }
}
