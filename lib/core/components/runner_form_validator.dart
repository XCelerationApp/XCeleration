/// Pure validation logic for runner input forms.
///
/// Both the live (debounced) validation and the pre-submit sync validation
/// call these methods, ensuring a single source of truth for all rules.
class RunnerFormValidator {
  RunnerFormValidator._();

  /// Returns an error message if [value] is not a valid runner name, else null.
  static String? validateName(String value) {
    if (value.isEmpty) return 'Please enter a name';
    return null;
  }

  /// Returns an error message if [value] is not a valid grade (9–12), else null.
  static String? validateGrade(String value) {
    if (value.isEmpty) return 'Please enter a grade';
    final grade = int.tryParse(value);
    if (grade == null) return 'Please enter a valid grade number';
    if (grade < 9 || grade > 12) return 'Grade must be between 9 and 12';
    return null;
  }

  /// Returns an error message if [value] fails format checks for a bib number,
  /// else null. Does not check uniqueness — that requires an async DB call.
  static String? validateBibFormat(String value) {
    if (value.isEmpty) return 'Please enter a bib number';
    final bib = int.tryParse(value);
    if (bib == null) return 'Please enter a valid bib number';
    if (bib <= 0) return 'Please enter a bib number greater than 0';
    return null;
  }
}
