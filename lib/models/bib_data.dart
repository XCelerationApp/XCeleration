import 'package:flutter/material.dart';

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

class BibRecordsProvider with ChangeNotifier {
  List<BibRecord> _bibRecords = [];
  List<TextEditingController> _controllers = [];
  List<FocusNode> _focusNodes = [];

  List<BibRecord> get bibRecords => _bibRecords;
  List<TextEditingController> get controllers => _controllers;
  List<FocusNode> get focusNodes => _focusNodes;

  void addBibRecord(BibRecord record) {
    _bibRecords.add(record);
    _controllers.add(TextEditingController(text: record.bibNumber));
    _focusNodes.add(FocusNode());
    notifyListeners();
  }

  void updateBibRecord(int index, String bibNumber) {
    _bibRecords[index].bibNumber = bibNumber;
    notifyListeners();
  }

  void removeBibRecord(int index) {
    _bibRecords.removeAt(index);
    _controllers.removeAt(index);
    _focusNodes.removeAt(index);
    notifyListeners();
  }

  void clearBibRecords() {
    _bibRecords.clear();
    _controllers.clear();
    _focusNodes.clear();
    notifyListeners();
  }
}