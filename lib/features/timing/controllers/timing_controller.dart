import 'package:flutter/material.dart';
import '../../../shared/constants/app_constants.dart' as constants;
import '../../../core/services/event_bus.dart';
import '../../../core/utils/logger.dart';
import '../models/timing_record.dart';
import '../models/bib_record.dart';
import '../services/timing_service.dart';

/// Consolidated controller for timing functionality
/// Combines timer and bib number recording capabilities
class TimingController extends ChangeNotifier {
  final TimingService _timingService;
  final EventBus _eventBus;

  // Timer state
  bool _isTimerRunning = false;
  DateTime? _startTime;
  Duration _elapsedTime = Duration.zero;

  // Records
  final List<TimingRecord> _timingRecords = [];
  final List<BibRecord> _bibRecords = [];

  // Current state
  TimingRecord? _selectedRecord;
  BibRecord? _currentBibRecord;
  bool _isLoading = false;
  String? _errorMessage;

  TimingController({
    required TimingService timingService,
    required EventBus eventBus,
  })  : _timingService = timingService,
        _eventBus = eventBus;

  // Getters
  bool get isTimerRunning => _isTimerRunning;
  DateTime? get startTime => _startTime;
  Duration get elapsedTime => _elapsedTime;
  List<TimingRecord> get timingRecords => List.unmodifiable(_timingRecords);
  List<BibRecord> get bibRecords => List.unmodifiable(_bibRecords);
  TimingRecord? get selectedRecord => _selectedRecord;
  BibRecord? get currentBibRecord => _currentBibRecord;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Start the race timer
  Future<void> startTimer() async {
    try {
      _setLoading(true);
      _clearError();

      _startTime = DateTime.now();
      _isTimerRunning = true;
      _elapsedTime = Duration.zero;

      Logger.d('Timer started at ${_startTime}');
      _eventBus.fire(constants.EventTypes.timingStarted, _startTime);

      notifyListeners();
    } catch (e) {
      _setError('Failed to start timer: $e');
      Logger.e('Error starting timer', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Stop the race timer
  Future<void> stopTimer() async {
    try {
      _setLoading(true);
      _clearError();

      _isTimerRunning = false;
      final stopTime = DateTime.now();

      if (_startTime != null) {
        _elapsedTime = stopTime.difference(_startTime!);
      }

      Logger.d('Timer stopped. Total elapsed time: $_elapsedTime');
      _eventBus.fire(constants.EventTypes.timingStopped, _elapsedTime);

      notifyListeners();
    } catch (e) {
      _setError('Failed to stop timer: $e');
      Logger.e('Error stopping timer', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Record a timing entry
  Future<void> recordTime() async {
    if (!_isTimerRunning || _startTime == null) {
      _setError('Timer is not running');
      return;
    }

    try {
      _setLoading(true);
      _clearError();

      final now = DateTime.now();
      final elapsed = now.difference(_startTime!);

      final record = TimingRecord(
        elapsedTime: _formatDuration(elapsed),
        timestamp: now,
        place: _timingRecords.length + 1,
      );

      _timingRecords.add(record);
      await _timingService.saveTimingRecord(record);

      Logger.d('Recorded time: ${record.elapsedTime}');
      _eventBus.fire(constants.EventTypes.dataReceived, record);

      notifyListeners();
    } catch (e) {
      _setError('Failed to record time: $e');
      Logger.e('Error recording time', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Add a bib number record
  Future<void> addBibRecord(String bibNumber,
      {String? name, String? school}) async {
    try {
      _setLoading(true);
      _clearError();

      // Validate bib number
      if (!constants.ValidationPatterns.bibNumber.hasMatch(bibNumber)) {
        _setError('Invalid bib number format');
        return;
      }

      // Check for duplicates
      final existingRecord =
          _bibRecords.where((r) => r.bibNumber == bibNumber).firstOrNull;
      if (existingRecord != null) {
        _setError('Bib number $bibNumber already recorded');
        return;
      }

      final record = BibRecord(
        bibNumber: bibNumber,
        name: name ?? '',
        school: school ?? '',
        timestamp: DateTime.now(),
        isValidated: true,
      );

      _bibRecords.add(record);
      _currentBibRecord = record;

      await _timingService.saveBibRecord(record);

      Logger.d('Added bib record: $bibNumber');
      notifyListeners();
    } catch (e) {
      _setError('Failed to add bib record: $e');
      Logger.e('Error adding bib record', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Associate a bib number with a timing record
  Future<void> associateBibWithTime(
      String bibNumber, TimingRecord timingRecord) async {
    try {
      _setLoading(true);
      _clearError();

      final updatedRecord = timingRecord.copyWith(
        bibNumber: bibNumber,
        isConfirmed: true,
      );

      final index = _timingRecords.indexOf(timingRecord);
      if (index != -1) {
        _timingRecords[index] = updatedRecord;
        await _timingService.updateTimingRecord(updatedRecord);

        Logger.d(
            'Associated bib $bibNumber with time ${timingRecord.elapsedTime}');
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to associate bib with time: $e');
      Logger.e('Error associating bib with time', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Select a timing record
  void selectRecord(TimingRecord? record) {
    _selectedRecord = record;
    notifyListeners();
  }

  /// Clear all records
  Future<void> clearAllRecords() async {
    try {
      _setLoading(true);
      _clearError();

      _timingRecords.clear();
      _bibRecords.clear();
      _selectedRecord = null;
      _currentBibRecord = null;

      await _timingService.clearAllRecords();

      Logger.d('Cleared all timing records');
      notifyListeners();
    } catch (e) {
      _setError('Failed to clear records: $e');
      Logger.e('Error clearing records', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Load existing records
  Future<void> loadRecords() async {
    try {
      _setLoading(true);
      _clearError();

      final timingRecords = await _timingService.getTimingRecords();
      final bibRecords = await _timingService.getBibRecords();

      _timingRecords.clear();
      _timingRecords.addAll(timingRecords);

      _bibRecords.clear();
      _bibRecords.addAll(bibRecords);

      Logger.d(
          'Loaded ${timingRecords.length} timing records and ${bibRecords.length} bib records');
      notifyListeners();
    } catch (e) {
      _setError('Failed to load records: $e');
      Logger.e('Error loading records', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Update elapsed time (for timer display)
  void updateElapsedTime() {
    if (_isTimerRunning && _startTime != null) {
      _elapsedTime = DateTime.now().difference(_startTime!);
      notifyListeners();
    }
  }

  /// Format duration as HH:MM:SS
  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) _clearError();
  }

  /// Set error message
  void _setError(String message) {
    _errorMessage = message;
    _isLoading = false;
  }

  /// Clear error message
  void _clearError() {
    _errorMessage = null;
  }

  @override
  void dispose() {
    // Clean up any resources
    super.dispose();
  }
}
