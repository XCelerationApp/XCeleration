/// Returns the abbreviated label for a high-school grade number.
///
/// Maps 9 → 'Fr', 10 → 'So', 11 → 'Jr', 12 → 'Sr'.
/// Returns '-' for null or any value outside 9–12.
String gradeLabel(int? grade) {
  switch (grade) {
    case 9:
      return 'Fr';
    case 10:
      return 'So';
    case 11:
      return 'Jr';
    case 12:
      return 'Sr';
    default:
      return '-';
  }
}
