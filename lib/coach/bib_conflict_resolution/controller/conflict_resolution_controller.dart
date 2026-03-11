import 'package:flutter/foundation.dart';
import '../mock/conflict_mock_data.dart';

enum _FlowStep { summary, duplicateStep1, duplicateStep2, unknown, completion }

class _HistoryEntry {
  const _HistoryEntry({
    required this.step,
    required this.conflictIndex,
    this.chosenOccurrence,
    this.restoredRunner,
    this.undoNewRunner = false,
  });

  final _FlowStep step;
  final int conflictIndex;

  /// Which duplicate occurrence was marked correct (1 or 2). Null for non-duplicates.
  final int? chosenOccurrence;

  /// Runner to restore to the unassigned list when going back.
  final MockRunner? restoredRunner;

  /// Whether to decrement newRunnersCreated when going back.
  final bool undoNewRunner;
}

class ConflictResolutionController extends ChangeNotifier {
  ConflictResolutionController()
      : _unassignedRunners = List.from(ConflictMockData.allUnassignedRunners);

  final List<MockBibConflict> _conflicts = ConflictMockData.conflicts;
  final List<MockRunner> _unassignedRunners;
  final List<_HistoryEntry> _history = [];

  _FlowStep _currentStep = _FlowStep.summary;
  int _currentConflictIndex = 0;
  int? _chosenDuplicateOccurrence;
  bool _isGoingBack = false;

  int _duplicatesResolved = 0;
  int _runnersAssigned = 0;
  int _newRunnersCreated = 0;

  // --- State checks ---
  bool get isOnSummary => _currentStep == _FlowStep.summary;
  bool get isOnDuplicateStep1 => _currentStep == _FlowStep.duplicateStep1;
  bool get isOnDuplicateStep2 => _currentStep == _FlowStep.duplicateStep2;
  bool get isOnUnknown => _currentStep == _FlowStep.unknown;
  bool get isOnCompletion => _currentStep == _FlowStep.completion;
  bool get isGoingBack => _isGoingBack;
  bool get canGoBack => _history.isNotEmpty;

  // --- Data ---
  MockBibConflict get currentConflict => _conflicts[_currentConflictIndex];
  int get currentConflictIndex => _currentConflictIndex;
  int get totalConflicts => _conflicts.length;
  int? get chosenDuplicateOccurrence => _chosenDuplicateOccurrence;

  int get resolvedCount =>
      _currentStep == _FlowStep.completion ? _conflicts.length : _currentConflictIndex;

  int get duplicatesResolved => _duplicatesResolved;
  int get runnersAssigned => _runnersAssigned;
  int get newRunnersCreated => _newRunnersCreated;

  /// Key that changes on every step/conflict transition, used by the inner AnimatedSwitcher.
  String get stepKey => '${_currentStep.name}_$_currentConflictIndex';

  /// Key that changes only on major state transitions (summary/conflicts/completion).
  String get outerStateKey {
    if (_currentStep == _FlowStep.summary) return 'summary';
    if (_currentStep == _FlowStep.completion) return 'completion';
    return 'conflicts';
  }

  /// All unassigned runners sorted by proximity to [targetBib].
  List<MockRunner> runnersNearBib(int targetBib) {
    final sorted = List<MockRunner>.from(_unassignedRunners);
    sorted.sort((a, b) =>
        (a.bibNumber - targetBib).abs().compareTo((b.bibNumber - targetBib).abs()));
    return sorted;
  }

  /// All bib numbers currently known (assigned + unassigned), for new-runner validation.
  Set<int> get allKnownBibs {
    final bibs = <int>{};
    for (final conflict in _conflicts) {
      switch (conflict) {
        case MockDuplicateConflict(:final bibNumber):
          bibs.add(bibNumber);
        case MockUnknownConflict(:final enteredBib):
          bibs.add(enteredBib);
      }
      for (final entry in conflict.surroundingFinishers) {
        bibs.add(entry.bibNumber);
      }
    }
    for (final runner in _unassignedRunners) {
      bibs.add(runner.bibNumber);
    }
    return bibs;
  }

  // --- Actions ---

  void startResolving() {
    _isGoingBack = false;
    _unassignedRunners
      ..clear()
      ..addAll(ConflictMockData.allUnassignedRunners);
    _history
      ..clear()
      ..add(const _HistoryEntry(step: _FlowStep.summary, conflictIndex: 0));
    _currentConflictIndex = 0;
    _chosenDuplicateOccurrence = null;
    _duplicatesResolved = 0;
    _runnersAssigned = 0;
    _newRunnersCreated = 0;
    _currentStep = _stepForConflict(_conflicts[0]);
    notifyListeners();
  }

  void chooseDuplicateOccurrence(int occurrence) {
    _isGoingBack = false;
    _history.add(_HistoryEntry(
      step: _FlowStep.duplicateStep1,
      conflictIndex: _currentConflictIndex,
    ));
    _chosenDuplicateOccurrence = occurrence;
    _currentStep = _FlowStep.duplicateStep2;
    notifyListeners();
  }

  void assignRunner(MockRunner runner) {
    _isGoingBack = false;
    _history.add(_HistoryEntry(
      step: _currentStep,
      conflictIndex: _currentConflictIndex,
      chosenOccurrence: _chosenDuplicateOccurrence,
      restoredRunner: runner,
    ));
    _unassignedRunners.remove(runner);
    _runnersAssigned++;
    if (_currentStep == _FlowStep.duplicateStep2) _duplicatesResolved++;
    _advance();
  }

  void createNewRunner(String name, int bibNumber, {String? team, int? grade}) {
    _isGoingBack = false;
    _history.add(_HistoryEntry(
      step: _currentStep,
      conflictIndex: _currentConflictIndex,
      chosenOccurrence: _chosenDuplicateOccurrence,
      undoNewRunner: true,
    ));
    _newRunnersCreated++;
    if (_currentStep == _FlowStep.duplicateStep2) _duplicatesResolved++;
    _advance();
  }

  void goBack() {
    if (_history.isEmpty) return;
    _isGoingBack = true;
    final prev = _history.removeLast();

    if (prev.restoredRunner != null) {
      _unassignedRunners.add(prev.restoredRunner!);
      _runnersAssigned = (_runnersAssigned - 1).clamp(0, _runnersAssigned);
      if (prev.step == _FlowStep.duplicateStep2) {
        _duplicatesResolved = (_duplicatesResolved - 1).clamp(0, _duplicatesResolved);
      }
    }
    if (prev.undoNewRunner) {
      _newRunnersCreated = (_newRunnersCreated - 1).clamp(0, _newRunnersCreated);
      if (prev.step == _FlowStep.duplicateStep2) {
        _duplicatesResolved = (_duplicatesResolved - 1).clamp(0, _duplicatesResolved);
      }
    }

    _currentStep = prev.step;
    _currentConflictIndex = prev.conflictIndex;
    _chosenDuplicateOccurrence = prev.chosenOccurrence;
    notifyListeners();
  }

  void _advance() {
    final nextIndex = _currentConflictIndex + 1;
    if (nextIndex >= _conflicts.length) {
      _currentStep = _FlowStep.completion;
    } else {
      _currentConflictIndex = nextIndex;
      _chosenDuplicateOccurrence = null;
      _currentStep = _stepForConflict(_conflicts[nextIndex]);
    }
    notifyListeners();
  }

  _FlowStep _stepForConflict(MockBibConflict conflict) => switch (conflict) {
        MockDuplicateConflict() => _FlowStep.duplicateStep1,
        MockUnknownConflict() => _FlowStep.unknown,
      };
}
