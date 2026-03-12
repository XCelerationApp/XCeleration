import 'package:flutter/foundation.dart';
import '../mock/conflict_mock_data.dart';

enum _FlowStep { summary, duplicateStep1, unknown, completion }

typedef ResolutionEntry = ({
  String conflictLabel,
  bool wasCreate,
  String runnerName,
  int bib,
  String team,
});

class ConflictResolutionController extends ChangeNotifier {
  ConflictResolutionController({
    List<MockBibConflict>? conflicts,
    List<MockRunner>? unassignedRunners,
  })  : _initialConflicts =
            List.unmodifiable(conflicts ?? ConflictMockData.conflicts),
        _initialUnassignedRunners = List.unmodifiable(
            unassignedRunners ?? ConflictMockData.allUnassignedRunners),
        _conflicts = List.from(conflicts ?? ConflictMockData.conflicts),
        _unassignedRunners = List.from(
            unassignedRunners ?? ConflictMockData.allUnassignedRunners);

  final List<MockBibConflict> _initialConflicts;
  final List<MockRunner> _initialUnassignedRunners;

  final List<MockBibConflict> _conflicts;
  final List<MockRunner> _unassignedRunners;
  final List<ResolutionEntry> _resolutionLog = [];

  _FlowStep _currentStep = _FlowStep.summary;
  int _currentConflictIndex = 0;
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
  bool get isOnUnknown => _currentStep == _FlowStep.unknown;
  bool get isOnCompletion => _currentStep == _FlowStep.completion;
  bool get isGoingBack => _isGoingBack;

  /// True whenever the back button should be active.
  bool get canGoBack =>
      _hasPending ||
      _currentConflictIndex > 0 ||
      _currentStep == _FlowStep.completion;

  bool get hasPending => _hasPending;
  String get pendingLabel => _pendingLabel;

  // --- Data ---
  MockBibConflict get currentConflict => _conflicts[_currentConflictIndex];
  int get currentConflictIndex => _currentConflictIndex;
  int get totalConflicts => _conflicts.length;

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

  /// Unique team names derived from the initial runner list, sorted alphabetically.
  /// Widgets use this instead of accessing ConflictMockData directly.
  List<String> get teams {
    final names = _initialUnassignedRunners.map((r) => r.team).toSet().toList()
      ..sort();
    return names;
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
      ..addAll(_initialUnassignedRunners);
    _conflicts
      ..clear()
      ..addAll(_initialConflicts);
    _currentConflictIndex = 0;
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
  /// every other occurrence as an unknown into the queue, then advances directly
  /// to the first injected unknown. The known runner is implicitly confirmed at
  /// the correct position — no step-2 card is shown.
  void chooseDuplicateOccurrence(int correctPosition) {
    _isGoingBack = false;
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
    _duplicatesResolved++;
    _advance();
  }

  /// Resolves a 2-occurrence duplicate inline: stages the runner assigned to the
  /// leftover occurrence, and also records the duplicate as resolved on commit.
  /// Use this instead of [prepareAssign] when the leftover is handled within
  /// the duplicate card itself (no separate UnknownBibCard is shown).
  void prepareAssignForDuplicate(MockRunner runner, String label) {
    _isGoingBack = false;
    _unassignedRunners.remove(runner);
    _pendingAssignedRunner = runner;
    _pendingLabel = label;
    _pendingCommitAction = () {
      _duplicatesResolved++;
      _runnersAssigned++;
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

  /// Like [prepareAssignForDuplicate] but for a newly created runner.
  void prepareCreateForDuplicate(
      String name, int bib, String team, int? grade, String label) {
    _isGoingBack = false;
    _pendingAssignedRunner = null;
    _pendingLabel = label;
    _pendingCommitAction = () {
      _duplicatesResolved++;
      _newRunnersCreated++;
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

  /// Stages an existing runner as the resolution. Removes from unassigned list
  /// immediately; call [commitPending] to finalise or [undoPending] to revert.
  void prepareAssign(MockRunner runner, String label) {
    _isGoingBack = false;
    _unassignedRunners.remove(runner);
    _pendingAssignedRunner = runner;
    _pendingLabel = label;
    _pendingCommitAction = () {
      _runnersAssigned++;
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

  /// Navigates backward:
  /// 1. If a resolution is pending, undoes it (undo-toast path).
  /// 2. If on the completion screen, unresolves the last conflict and returns to it.
  /// 3. Otherwise, steps back one conflict and removes its log entry.
  void goBack() {
    if (_hasPending) {
      undoPending();
      return;
    }
    _isGoingBack = true;
    if (_currentStep == _FlowStep.completion) {
      if (_resolutionLog.isNotEmpty) _resolutionLog.removeLast();
      _currentStep = _stepForConflict(_conflicts[_currentConflictIndex]);
      notifyListeners();
      return;
    }
    if (_currentConflictIndex > 0) {
      if (_resolutionLog.isNotEmpty) _resolutionLog.removeLast();
      _currentConflictIndex--;
      _currentStep = _stepForConflict(_conflicts[_currentConflictIndex]);
      notifyListeners();
    }
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
      _currentStep = _stepForConflict(_conflicts[nextIndex]);
    }
    notifyListeners();
  }

  _FlowStep _stepForConflict(MockBibConflict conflict) => switch (conflict) {
        MockDuplicateConflict() => _FlowStep.duplicateStep1,
        MockUnknownConflict() => _FlowStep.unknown,
      };
}
