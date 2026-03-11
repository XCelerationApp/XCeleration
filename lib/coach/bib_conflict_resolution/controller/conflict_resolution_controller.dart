import 'package:flutter/foundation.dart';
import '../mock/conflict_mock_data.dart';

enum _FlowStep { summary, duplicateStep1, duplicateStep2, unknown, completion }

typedef ResolutionEntry = ({
  String conflictLabel,
  bool wasCreate,
  String runnerName,
  int bib,
  String team,
});

class ConflictResolutionController extends ChangeNotifier {
  ConflictResolutionController()
      : _unassignedRunners = List.from(ConflictMockData.allUnassignedRunners),
        _conflicts = List.from(ConflictMockData.conflicts);

  final List<MockBibConflict> _conflicts;
  final List<MockRunner> _unassignedRunners;
  final List<ResolutionEntry> _resolutionLog = [];

  _FlowStep _currentStep = _FlowStep.summary;
  int _currentConflictIndex = 0;
  int? _chosenDuplicateOccurrence;
  bool _isGoingBack = false;

  bool _hasPending = false;
  String _pendingLabel = '';
  VoidCallback? _pendingCommitAction;
  MockRunner? _pendingAssignedRunner;

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
  bool get canGoBack => _hasPending;
  bool get hasPending => _hasPending;
  String get pendingLabel => _pendingLabel;

  // --- Data ---
  MockBibConflict get currentConflict => _conflicts[_currentConflictIndex];
  int get currentConflictIndex => _currentConflictIndex;
  int get totalConflicts => _conflicts.length;
  int? get chosenDuplicateOccurrence => _chosenDuplicateOccurrence;

  int get resolvedCount {
    if (_currentStep == _FlowStep.completion) return _conflicts.length;
    if (_hasPending) return _currentConflictIndex + 1;
    return _currentConflictIndex;
  }

  int get duplicatesResolved => _duplicatesResolved;
  int get runnersAssigned => _runnersAssigned;
  int get newRunnersCreated => _newRunnersCreated;
  List<ResolutionEntry> get resolutionLog => List.unmodifiable(_resolutionLog);

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
    _conflicts
      ..clear()
      ..addAll(ConflictMockData.conflicts);
    _currentConflictIndex = 0;
    _chosenDuplicateOccurrence = null;
    _hasPending = false;
    _pendingLabel = '';
    _pendingCommitAction = null;
    _pendingAssignedRunner = null;
    _resolutionLog.clear();
    _duplicatesResolved = 0;
    _runnersAssigned = 0;
    _newRunnersCreated = 0;
    _currentStep = _stepForConflict(_conflicts[0]);
    notifyListeners();
  }

  /// Splices [unknowns] into the conflict queue immediately after the current
  /// conflict index, then notifies. Used to inject leftover duplicate entries.
  void injectConflicts(List<MockUnknownConflict> unknowns) {
    _conflicts.insertAll(_currentConflictIndex + 1, unknowns);
    notifyListeners();
  }

  /// Records the correct occurrence position for a duplicate conflict, injects
  /// every other occurrence as an unknown into the queue, then advances to step 2.
  void chooseDuplicateOccurrence(int correctPosition) {
    _isGoingBack = false;
    _chosenDuplicateOccurrence = correctPosition;

    final conflict = _conflicts[_currentConflictIndex] as MockDuplicateConflict;
    final leftovers = conflict.occurrences
        .where((o) => o.position != correctPosition)
        .map((o) => MockUnknownConflict(
              enteredBib: conflict.bibNumber,
              position: o.position,
              formattedTime: o.formattedTime,
              surroundingFinishers: conflict.surroundingFinishers,
            ))
        .toList();

    injectConflicts(leftovers);
    _currentStep = _FlowStep.duplicateStep2;
    notifyListeners();
  }

  /// Stages an existing runner as the resolution. Removes from unassigned list
  /// immediately; call [commitPending] to finalise or [undoPending] to revert.
  void prepareAssign(MockRunner runner, String label) {
    _isGoingBack = false;
    _unassignedRunners.remove(runner);
    _pendingAssignedRunner = runner;
    _pendingLabel = label;
    _pendingCommitAction = () {
      _runnersAssigned++;
      if (_currentStep == _FlowStep.duplicateStep2) _duplicatesResolved++;
      _resolutionLog.add((
        conflictLabel: label,
        wasCreate: false,
        runnerName: runner.name,
        bib: runner.bibNumber,
        team: runner.team,
      ));
    };
    _hasPending = true;
    notifyListeners();
  }

  /// Stages a newly created runner as the resolution. Call [commitPending] to
  /// finalise or [undoPending] to revert.
  void prepareCreate(
      String name, int bib, String team, int? grade, String label) {
    _isGoingBack = false;
    _pendingAssignedRunner = null;
    _pendingLabel = label;
    _pendingCommitAction = () {
      _newRunnersCreated++;
      if (_currentStep == _FlowStep.duplicateStep2) _duplicatesResolved++;
      _resolutionLog.add((
        conflictLabel: label,
        wasCreate: true,
        runnerName: name,
        bib: bib,
        team: team,
      ));
    };
    _hasPending = true;
    notifyListeners();
  }

  /// Commits the pending resolution, appends to the log, and advances to the
  /// next conflict.
  void commitPending() {
    if (!_hasPending) return;
    _pendingCommitAction?.call();
    _clearPending();
    _advance();
  }

  /// Reverts the pending resolution. If an assign was staged, the runner is
  /// restored to the unassigned list.
  void undoPending() {
    if (!_hasPending) return;
    _isGoingBack = true;
    if (_pendingAssignedRunner != null) {
      _unassignedRunners.add(_pendingAssignedRunner!);
    }
    _clearPending();
    notifyListeners();
  }

  void goBack() {
    if (_hasPending) undoPending();
  }

  void _clearPending() {
    _hasPending = false;
    _pendingLabel = '';
    _pendingCommitAction = null;
    _pendingAssignedRunner = null;
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
