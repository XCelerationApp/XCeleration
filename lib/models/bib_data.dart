import 'package:flutter/material.dart';

class BibRecordsProvider with ChangeNotifier {
  List<Map<String, dynamic>> _bibRecords = [];
  List<TextEditingController> _controllers = [];
  List<FocusNode> _focusNodes = [];

  List<Map<String, dynamic>> get bibRecords => _bibRecords;
  List<TextEditingController> get controllers => _controllers;
  List<FocusNode> get focusNodes => _focusNodes;

  void addBibRecord(Map<String, dynamic> record) {
    _bibRecords.add(record);
    _controllers.add(TextEditingController(text: record['bib_number']));
    _focusNodes.add(FocusNode());
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