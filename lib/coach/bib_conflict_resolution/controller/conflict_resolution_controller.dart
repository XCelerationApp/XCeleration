import 'package:flutter/foundation.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import '../model/bib_conflict.dart';
import '../utils/bib_suggestions.dart';
import '../services/runner_creator.dart';

enum _FlowStep { summary, conflict, completion }

/// How a finish came to have its runner.
enum ResolutionKind {
  /// The runner whose bib it is: the finish the coach said was theirs.
  kept,

  /// A runner already in the race, picked from the list.
  assigned,

  /// A runner the coach added.
  created,
}

/// One finish the coach has settled: who finished at [place], and how.
typedef ResolutionEntry = ({
  int place,
  String bibNumber,
  ResolutionKind kind,
  RaceRunner raceRunner,
});

/// A resolution waiting out its undo toast.
class _Pending {
  const _Pending({
    required this.place,
    required this.bibNumber,
    required this.label,
    this.runner,
    this.newRunner,
  });

  final int place;
  final String bibNumber;
  final String label;

  /// Set when assigning a runner already in the race.
  final RaceRunner? runner;

  /// Set when adding a runner. Saved only when the toast runs out, so an
  /// undone creation never leaves a stray runner entered in the race.
  final NewRunner? newRunner;
}

/// Drives resolving the bib conflicts in a race's finish order.
///
/// Every resolution is recorded against the place it settles, and the result
/// is who finished at each of those places — which is what gets written back
/// into the finish order. The coach chooses the order: any conflict can be
/// opened from the summary, and finishing one moves on to the next still open.
class ConflictResolutionController extends ChangeNotifier {
  ConflictResolutionController({
    required List<BibConflict> conflicts,
    required List<RaceRunner> candidates,
    List<RaceRunner> roster = const [],
    required Set<String> knownBibs,
    Map<String, String> savedBibOwners = const {},
    required List<String> teams,
    required this.raceName,
    required Future<Result<RaceRunner>> Function(NewRunner) createRunner,
    Future<void> Function(RaceRunner)? withdrawRunner,
    this.timingConflictsNext = 0,
  })  : _withdrawRunner = withdrawRunner,
        _conflicts = List.unmodifiable(conflicts),
        _candidates = List.unmodifiable(candidates),
        _roster = List.unmodifiable(roster),
        _knownBibs = Set.unmodifiable(knownBibs),
        _savedBibOwners = Map.unmodifiable(savedBibOwners),
        _teams = List.unmodifiable(teams),
        _createRunner = createRunner;

  final List<BibConflict> _conflicts;

  /// How many timing conflicts are still to sort out once the bibs are, so
  /// the last page can say what comes next instead of "all resolved".
  final int timingConflictsNext;

  /// Runners in the race who are not placed anywhere in the finish order —
  /// who a mistyped bib might really have been.
  final List<RaceRunner> _candidates;

  /// Everyone in the race, placed or not, for each team's block of bibs.
  final List<RaceRunner> _roster;

  /// Bibs already taken, so an added runner cannot reuse one.
  final Set<String> _knownBibs;

  /// Bibs held by runners saved on this phone who are not in this race, with
  /// each one's name. A bib belongs to one saved runner at most, so a runner
  /// added with one of these must be that runner.
  final Map<String, String> _savedBibOwners;
  Map<String, String> get savedBibOwners => _savedBibOwners;
  final List<String> _teams;
  final Future<Result<RaceRunner>> Function(NewRunner) _createRunner;

  /// Takes a runner added here back out of the race, once the answer that
  /// added them is taken back: they used to stay entered, with no finish.
  final Future<void> Function(RaceRunner)? _withdrawRunner;

  /// Shown in the header, so the coach knows which race this is.
  final String raceName;

  _FlowStep _step = _FlowStep.summary;
  int _current = 0;
  bool _isGoingBack = false;

  /// Who finished at each settled place.
  final Map<int, ResolutionEntry> _settled = {};

  /// For each duplicate being worked on, the place the coach said belongs to
  /// the runner whose bib it is.
  final Map<int, int> _ownerPlace = {};

  _Pending? _pending;
  AppError? _error;
  bool _committing = false;

  // --- Flow state ---------------------------------------------------------

  bool get isOnSummary => _step == _FlowStep.summary;
  bool get isOnConflict => _step == _FlowStep.conflict;
  bool get isOnCompletion => _step == _FlowStep.completion;
  bool get isGoingBack => _isGoingBack;
  bool get canGoBack => !isOnSummary;

  /// Changes whenever the card on screen changes, including between the
  /// leftover finishes of one repeated bib, so each gets its own transition.
  String get stepKey =>
      '${_step.name}_${_current}_${_ownerPlace[_current]}_${currentLeftover?.place}';

  /// Changes only between the summary, the conflicts and the review.
  String get outerStateKey => _step.name;

  bool get hasPending => _pending != null;
  String get pendingLabel => _pending?.label ?? '';

  /// Why the last action failed, for the screen to show.
  AppError? get error => _error;

  // --- The conflicts ------------------------------------------------------

  List<BibConflict> get conflicts => _conflicts;
  int get totalConflicts => _conflicts.length;
  int get duplicateCount => _conflicts.whereType<DuplicateBibConflict>().length;
  int get unknownCount => _conflicts.whereType<UnknownBibConflict>().length;

  BibConflict get currentConflict => _conflicts[_current];
  int get currentConflictIndex => _current;

  /// The places a conflict needs a runner for.
  static List<int> placesOf(BibConflict conflict) => switch (conflict) {
        DuplicateBibConflict(:final occurrences) =>
          [for (final o in occurrences) o.place],
        UnknownBibConflict(:final occurrence) => [occurrence.place],
      };

  bool isResolved(int index) =>
      placesOf(_conflicts[index]).every(_settled.containsKey);

  int get resolvedCount =>
      [for (var i = 0; i < _conflicts.length; i++) i].where(isResolved).length;

  /// The place chosen as the bib owner's, for the duplicate on screen.
  int? get chosenPlace => _ownerPlace[_current];

  /// The next finish of the duplicate on screen that still needs a runner,
  /// once the owner's finish has been chosen.
  ConflictOccurrence? get currentLeftover {
    final conflict = _conflicts.isEmpty ? null : _conflicts[_current];
    final owner = _ownerPlace[_current];
    if (conflict is! DuplicateBibConflict || owner == null) return null;
    for (final occurrence in conflict.occurrences) {
      if (occurrence.place == owner) continue;
      if (_settled.containsKey(occurrence.place)) continue;
      return occurrence;
    }
    return null;
  }

  /// How many of the duplicate's other finishes still need a runner.
  int get leftoversRemaining {
    final conflict = _conflicts[_current];
    final owner = _ownerPlace[_current];
    if (conflict is! DuplicateBibConflict || owner == null) return 0;
    return conflict.occurrences
        .where((o) => o.place != owner && !_settled.containsKey(o.place))
        .length;
  }

  // --- Runners ------------------------------------------------------------

  List<String> get teams => _teams;

  /// Runners already given a finish here, staged or settled.
  Set<String> get _usedBibs => {
        for (final entry in _settled.values) ?entry.raceRunner.runner.bibNumber,
        ?_pending?.runner?.runner.bibNumber,
      };

  /// The runners still free to be given a finish, nearest bib number first:
  /// a mistyped bib is usually a digit or two from the real one.
  List<RaceRunner> runnersNearBib(String bib) {
    final target = int.tryParse(bib);
    final free = _freeRunners;
    if (target == null) return free;
    int distance(RaceRunner r) {
      final value = int.tryParse(r.runner.bibNumber ?? '');
      return value == null ? 1 << 30 : (value - target).abs();
    }

    return free..sort((a, b) => distance(a).compareTo(distance(b)));
  }

  List<RaceRunner> get _freeRunners {
    final used = _usedBibs;
    return _candidates
        .where((r) => !used.contains(r.runner.bibNumber))
        .toList();
  }

  /// Who [bib] was most likely meant to be, with why: runners not placed
  /// yet whose bib is one slip away, then the team whose bibs it falls
  /// among.
  List<RunnerSuggestion> suggestionsFor(String bib) => suggestRunnersForBib(
        bib,
        free: _freeRunners,
        roster: _roster.isEmpty ? _candidates : _roster,
      );

  /// Every bib already taken, so an added runner gets one of their own.
  Set<String> get allKnownBibs => {
        ..._knownBibs,
        for (final entry in _settled.values)
          if (entry.kind == ResolutionKind.created)
            ?entry.raceRunner.runner.bibNumber,
        ?_pending?.newRunner?.bibNumber,
      };

  /// The next bib number nobody has, in this race or saved from another, for
  /// a runner added in place of a bib that turned out to be someone else's.
  String get nextFreeBib {
    final taken = {...allKnownBibs, ..._savedBibOwners.keys};
    var highest = 0;
    for (final bib in taken) {
      final value = int.tryParse(bib);
      if (value != null && value > highest) highest = value;
    }
    var next = highest + 1;
    while (taken.contains('$next')) {
      next++;
    }
    return '$next';
  }

  // --- Results ------------------------------------------------------------

  /// Every settled finish, in finish order, for the review screen.
  List<ResolutionEntry> get resolutionLog =>
      _settled.values.toList()..sort((a, b) => a.place.compareTo(b.place));

  /// Who finished at each settled place — what goes back into the results.
  Map<int, RaceRunner> get resolvedByPlace => {
        for (final entry in _settled.entries) entry.key: entry.value.raceRunner,
      };

  /// Who finished at each place of the conflicts fully resolved, kept when
  /// the coach leaves part way: leaving used to throw every answer away. A
  /// repeated bib half done is left out, as its runner would otherwise be
  /// in the results twice.
  Map<int, RaceRunner> get finishedByPlace => {
        for (var i = 0; i < _conflicts.length; i++)
          if (isResolved(i))
            for (final place in placesOf(_conflicts[i]))
              place: _settled[place]!.raceRunner,
      };

  // --- Navigation ---------------------------------------------------------

  /// Opens the first conflict still open, or the review if there is none.
  void startResolving() {
    _isGoingBack = false;
    _error = null;
    _openNextOpen(from: 0);
    notifyListeners();
  }

  /// Opens [index] from the summary. A conflict already settled is reopened
  /// to be done again: that is how the coach changes an answer.
  void openConflict(int index) {
    if (index < 0 || index >= _conflicts.length) return;
    _isGoingBack = false;
    _error = null;
    _clear(index);
    _current = index;
    _step = _FlowStep.conflict;
    notifyListeners();
  }

  /// Steps back: an undo waiting on its toast first, then the owner's finish
  /// chosen for a repeated bib, then out to the summary.
  void goBack() {
    if (_pending != null) {
      undoPending();
      return;
    }
    _isGoingBack = true;
    _error = null;
    if (isOnConflict && _ownerPlace.containsKey(_current)) {
      _clear(_current);
    } else if (!isOnSummary) {
      _step = _FlowStep.summary;
    }
    notifyListeners();
  }

  // --- Resolving ----------------------------------------------------------

  /// The coach says [place] is the finish of the runner whose bib this is.
  /// Their other finishes each need a runner of their own next.
  void chooseDuplicateOccurrence(int place) {
    final conflict = _conflicts[_current];
    if (conflict is! DuplicateBibConflict) return;
    if (!placesOf(conflict).contains(place)) return;
    _isGoingBack = false;
    _ownerPlace[_current] = place;
    _settled[place] = (
      place: place,
      bibNumber: conflict.bibNumber,
      kind: ResolutionKind.kept,
      raceRunner: conflict.runner,
    );
    _afterSettling();
  }

  /// Gives an unrecognised bib's finish to [runner], pending the undo toast.
  void prepareAssign(RaceRunner runner, String label) {
    final conflict = _conflicts[_current];
    if (conflict is! UnknownBibConflict) return;
    _stage(_Pending(
      place: conflict.occurrence.place,
      bibNumber: conflict.bibNumber,
      label: label,
      runner: runner,
    ));
  }

  /// Gives a repeated bib's leftover finish to [runner], pending the toast.
  void prepareAssignForDuplicate(RaceRunner runner, String label) {
    final leftover = currentLeftover;
    if (leftover == null) return;
    _stage(_Pending(
      place: leftover.place,
      bibNumber: currentConflict.bibNumber,
      label: label,
      runner: runner,
    ));
  }

  /// Gives an unrecognised bib's finish to a runner the coach is adding.
  void prepareCreate(
      String name, String bib, String team, int grade, String label) {
    final conflict = _conflicts[_current];
    if (conflict is! UnknownBibConflict) return;
    _stage(_Pending(
      place: conflict.occurrence.place,
      bibNumber: conflict.bibNumber,
      label: label,
      newRunner:
          NewRunner(name: name, bibNumber: bib, teamName: team, grade: grade),
    ));
  }

  /// Gives a repeated bib's leftover finish to a runner the coach is adding.
  void prepareCreateForDuplicate(
      String name, String bib, String team, int grade, String label) {
    final leftover = currentLeftover;
    if (leftover == null) return;
    _stage(_Pending(
      place: leftover.place,
      bibNumber: currentConflict.bibNumber,
      label: label,
      newRunner:
          NewRunner(name: name, bibNumber: bib, teamName: team, grade: grade),
    ));
  }

  /// Settles the pending resolution once its toast runs out. An added runner
  /// is saved now; if that fails, nothing is settled and the coach is told.
  Future<void> commitPending() async {
    final pending = _pending;
    if (pending == null || _committing) return;
    _committing = true;
    try {
      RaceRunner runner;
      ResolutionKind kind;
      if (pending.newRunner != null) {
        final result = await _createRunner(pending.newRunner!);
        switch (result) {
          case Success(:final value):
            runner = value;
            kind = ResolutionKind.created;
          case Failure(:final error):
            _pending = null;
            _error = error;
            notifyListeners();
            return;
        }
      } else {
        runner = pending.runner!;
        kind = ResolutionKind.assigned;
      }
      _pending = null;
      _settled[pending.place] = (
        place: pending.place,
        bibNumber: pending.bibNumber,
        kind: kind,
        raceRunner: runner,
      );
      _afterSettling();
    } finally {
      _committing = false;
    }
  }

  /// Takes back the resolution waiting on its toast.
  void undoPending() {
    if (_pending == null) return;
    _pending = null;
    _isGoingBack = true;
    notifyListeners();
  }

  void dismissError() {
    _error = null;
    notifyListeners();
  }

  // --- Internals ----------------------------------------------------------

  void _withdraw(RaceRunner runner) {
    final withdraw = _withdrawRunner;
    if (withdraw == null) return;
    withdraw(runner).catchError((Object e) {
      Logger.e('Could not take an added runner back out of the race: $e');
    });
  }

  /// Takes back out of the race the runners added for conflicts left
  /// unfinished, as leaving keeps only the finished ones. Call when leaving.
  void withdrawUnfinished() {
    for (var i = 0; i < _conflicts.length; i++) {
      if (isResolved(i)) continue;
      for (final place in placesOf(_conflicts[i])) {
        final entry = _settled[place];
        if (entry?.kind == ResolutionKind.created) _withdraw(entry!.raceRunner);
      }
    }
  }

  void _stage(_Pending pending) {
    _isGoingBack = false;
    _error = null;
    _pending = pending;
    notifyListeners();
  }

  /// Stays on the conflict while it still has a finish to settle, otherwise
  /// moves on to the next one still open.
  void _afterSettling() {
    if (!isResolved(_current)) {
      notifyListeners();
      return;
    }
    _openNextOpen(from: _current + 1);
    notifyListeners();
  }

  /// Opens the first open conflict at or after [from], then any before it,
  /// or the review when none is left.
  void _openNextOpen({required int from}) {
    final order = [
      for (var i = from; i < _conflicts.length; i++) i,
      for (var i = 0; i < from && i < _conflicts.length; i++) i,
    ];
    for (final index in order) {
      if (!isResolved(index)) {
        _current = index;
        _step = _FlowStep.conflict;
        return;
      }
    }
    _step = _FlowStep.completion;
  }

  /// Forgets everything settled for conflict [index], so it can be redone.
  void _clear(int index) {
    for (final place in placesOf(_conflicts[index])) {
      final entry = _settled.remove(place);
      if (entry?.kind == ResolutionKind.created) _withdraw(entry!.raceRunner);
    }
    _ownerPlace.remove(index);
    if (_pending != null &&
        placesOf(_conflicts[index]).contains(_pending!.place)) {
      _pending = null;
    }
  }
}
