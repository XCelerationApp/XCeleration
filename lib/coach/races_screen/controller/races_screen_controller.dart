import 'package:flutter/material.dart';
import '../../../utils/database_helper.dart';

class RacesScreenController with ChangeNotifier {
  bool _isLoading = false;
  List<Map<String, dynamic>> _races = [];
  String _selectedFilter = 'All';
  
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get races => _races;
  String get selectedFilter => _selectedFilter;
  
  // Constructor to initialize the controller
  RacesScreenController() {
    loadRaces();
  }
  
  // Load races from the database
  Future<void> loadRaces() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final List<dynamic> allRaces = await DatabaseHelper.instance.getAllRaces(getState: false);
      
      // Apply filter if needed
      if (_selectedFilter != 'All') {
        _races = allRaces.where((race) {
          // Check if race is a Map or a Race object
          final flowState = race is Map ? race['flow_state'] : race.flowState;
          return flowState == _selectedFilter.toLowerCase().replaceAll(' ', '_');
        }).map<Map<String, dynamic>>((race) {
          // If it's already a Map, return it as is, otherwise convert to Map
          return race is Map ? Map<String, dynamic>.from(race) : race.toJson();
        }).toList();
      } else {
        _races = allRaces.map<Map<String, dynamic>>((race) {
          // If it's already a Map, return it as is, otherwise convert to Map
          return race is Map ? Map<String, dynamic>.from(race) : race.toJson();
        }).toList();
      }
    } catch (e) {
      debugPrint('Error loading races: $e');
      _races = [];
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  // Change the filter and reload races
  void changeFilter(String filter) {
    _selectedFilter = filter;
    loadRaces();
  }
  
  // Delete a race
  Future<void> deleteRace(int raceId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await DatabaseHelper.instance.deleteRace(raceId);
      await loadRaces();
    } catch (e) {
      debugPrint('Error deleting race: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }
}
