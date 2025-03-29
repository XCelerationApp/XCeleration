class BibRecord {
  String bibNumber;
  List<double> confidences;
  String name;
  String school;
  Map<String, bool> flags;
  
  BibRecord({
    this.bibNumber = '',
    this.confidences = const [],
    this.name = '',
    this.school = '',
  }) : flags = {
    'duplicate_bib_number': false,
    'not_in_database': false,
    'low_confidence_score': false,
  };

  bool get hasErrors => flags.values.any((flag) => flag);
  bool get isValid => !hasErrors && bibNumber.isNotEmpty;
}
