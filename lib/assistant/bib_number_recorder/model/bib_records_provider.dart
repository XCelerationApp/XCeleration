import 'package:flutter/material.dart';
import '../../../coach/race_screen/widgets/runner_record.dart';

class BibRecordsProvider with ChangeNotifier {
  final List<RunnerRecord> _bibRecords = [];
  final List<TextEditingController> controllers = [];
  final List<FocusNode> focusNodes = [];
  bool _isKeyboardVisible = false;

  List<RunnerRecord> get bibRecords => _bibRecords;
  bool get isKeyboardVisible => _isKeyboardVisible;

  void setKeyboardVisible(bool visible) {
    _isKeyboardVisible = visible;
    notifyListeners();
  }

  // Ensures that all collections have the same length
  bool get _collectionsInSync => 
      _bibRecords.length == controllers.length && 
      controllers.length == focusNodes.length;

  // Synchronizes collections to match bibRecords length
  void _syncCollections() {
    // If collections are out of sync, reset them
    if (!_collectionsInSync) {
      // Save existing bib records
      final existingRecords = List<RunnerRecord>.from(_bibRecords);
      
      // Clear and dispose all existing controllers and focus nodes
      for (var controller in controllers) {
        controller.dispose();
      }
      controllers.clear();
      
      for (var node in focusNodes) {
        node.dispose();
      }
      focusNodes.clear();
      
      // Reset records collection
      _bibRecords.clear();
      
      // Re-add all records with fresh controllers and focus nodes
      for (var record in existingRecords) {
        addBibRecord(record);
      }
    }
  }

  /// Adds a new bib record with the specified runner record.
  /// Returns the index of the added record.
  int addBibRecord(RunnerRecord record) {
    _bibRecords.add(record);
    
    final newIndex = _bibRecords.length - 1;
    final controller = TextEditingController(text: record.bib);
    controllers.add(controller);

    final focusNode = FocusNode();
    focusNode.addListener(() {
      if (focusNode.hasFocus != _isKeyboardVisible) {
        _isKeyboardVisible = focusNode.hasFocus;
        notifyListeners();
      }
    });
    focusNodes.add(focusNode);
    
    notifyListeners();
    
    return newIndex;
  }

  /// Updates an existing bib record at the specified index.
  void updateBibRecord(int index, RunnerRecord record) {
    if (index < 0 || index >= _bibRecords.length) return;
    
    // Ensure collections are in sync
    _syncCollections();
    
    _bibRecords[index] = record;
    
    // Only update the controller text if it differs to avoid cursor jumping
    if (index < controllers.length) {
      final currentText = controllers[index].text;
      if (currentText != record.bib) {
        controllers[index].text = record.bib;
      }
    }
    
    notifyListeners();
  }

  /// Removes a bib record at the specified index.
  void removeBibRecord(int index) {
    if (index < 0 || index >= _bibRecords.length) return;
    
    // Ensure collections are in sync before removing
    _syncCollections();
    
    if (index >= controllers.length || index >= focusNodes.length) return;
    
    _bibRecords.removeAt(index);
    
    // Clean up resources
    controllers[index].dispose();
    controllers.removeAt(index);
    
    focusNodes[index].dispose();
    focusNodes.removeAt(index);
    
    notifyListeners();
  }

  void clearBibRecords() {
    _bibRecords.clear();
    
    // Dispose all controllers and focus nodes
    for (var controller in controllers) {
      controller.dispose();
    }
    controllers.clear();
    
    for (var node in focusNodes) {
      node.dispose();
    }
    focusNodes.clear();
    
    notifyListeners();
  }

  @override
  void dispose() {
    // Clean up controllers and focus nodes
    for (var controller in controllers) {
      controller.dispose();
    }
    
    for (var node in focusNodes) {
      node.dispose();
    }
    
    super.dispose();
  }
}
