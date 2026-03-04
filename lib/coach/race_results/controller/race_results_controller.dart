import 'package:flutter/foundation.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/services/i_race_results_service.dart';
import 'package:xceleration/shared/services/race_results_service.dart';

class RaceResultsController extends ChangeNotifier {
  final IRaceResultsService _service;

  bool _isLoading = false;
  AppError? _error;
  RaceResultsData? _raceResultsData;

  RaceResultsController({required IRaceResultsService service})
      : _service = service;

  bool get isLoading => _isLoading;
  bool get hasError => _error != null;
  AppError? get error => _error;
  RaceResultsData? get raceResultsData => _raceResultsData;

  Future<void> loadRaceResults(MasterRace masterRace) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _service.calculateCompleteRaceResults(masterRace);

    switch (result) {
      case Success(:final value):
        _raceResultsData = value;
      case Failure(:final error):
        _error = error;
        Logger.e(
            '[RaceResultsController.loadRaceResults] ${error.originalException}');
    }

    _isLoading = false;
    notifyListeners();
  }
}
