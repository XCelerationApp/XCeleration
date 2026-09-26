import 'package:flutter/foundation.dart';

import '../../../core/app_error.dart';
import '../../../core/utils/logger.dart';
import '../../bib_conflict_resolution/utils/ordinal.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../shared/models/database/race_result.dart';
import '../../../shared/models/database/race_runner.dart';
import '../../../shared/models/database/team.dart';

/// One finish: who crossed the line and when. Its place is its position in
/// [EditResultsController.finishes].
@immutable
class EditableFinish {
  const EditableFinish({required this.runner, required this.time});

  final RaceRunner runner;
  final Duration time;

  EditableFinish withRunner(RaceRunner runner) =>
      EditableFinish(runner: runner, time: time);
}

/// Corrects a finished race's results: who finished at each place, their
/// time, and finishes that should not count at all.
///
/// Bib conflicts only catch a bib entered twice or one nobody has. A bib
/// mistyped as a runner who did not race goes through unnoticed, and a
/// disqualification or a wrong time needs fixing after the fact; before this
/// the only way out was deleting the race.
class EditResultsController extends ChangeNotifier {
  EditResultsController({
    required this.raceId,
    required List<RaceResult> results,
    required List<RaceRunner> raceRunners,
    required Future<void> Function(List<RaceResult>) save,
  })  : _raceRunners = [...raceRunners]..sort(_byBib),
        _save = save {
    final byId = {for (final r in raceRunners) r.runner.runnerId: r};
    final placed = [...results]..sort(
        (a, b) => (a.place ?? 1 << 30).compareTo(b.place ?? 1 << 30));
    _finishes = [
      for (final result in placed)
        if (result.runner != null)
          EditableFinish(
            runner: byId[result.runner!.runnerId] ??
                RaceRunner(
                  raceId: raceId,
                  runner: result.runner!,
                  team: result.team ?? const Team(name: ''),
                ),
            time: result.finishTime ?? Duration.zero,
          ),
    ];
  }

  final int raceId;
  final List<RaceRunner> _raceRunners;
  final Future<void> Function(List<RaceResult>) _save;

  late List<EditableFinish> _finishes;
  final List<(List<EditableFinish>, String)> _history = [];
  bool _saving = false;
  AppError? _error;

  List<EditableFinish> get finishes => List.unmodifiable(_finishes);

  /// Everyone in the race, by bib, for choosing who finished at a place.
  List<RaceRunner> get raceRunners => List.unmodifiable(_raceRunners);

  bool get hasChanges => _history.isNotEmpty;
  bool get isSaving => _saving;
  AppError? get error => _error;

  /// What Undo would take back, or null when there is nothing to undo.
  String? get undoLabel => _history.isEmpty ? null : _history.last.$2;

  /// The place [runner] finished, or null if they are not in the results.
  int? placeOf(RaceRunner runner) {
    final i = _finishes
        .indexWhere((f) => f.runner.runner.runnerId == runner.runner.runnerId);
    return i < 0 ? null : i + 1;
  }

  /// Makes [runner] the finisher at [index]. Someone already in the results
  /// swaps places with whoever was there; the times stay with the places.
  void assignRunner(int index, RaceRunner runner) {
    final current = _finishes[index].runner;
    if (current.runner.runnerId == runner.runner.runnerId) return;
    final other = placeOf(runner);
    _change(other == null
        ? '${runner.runner.name} at ${ordinal(index + 1)}'
        : 'Swap ${ordinal(index + 1)} and ${ordinal(other)}');
    _finishes[index] = _finishes[index].withRunner(runner);
    if (other != null) {
      _finishes[other - 1] = _finishes[other - 1].withRunner(current);
    }
    notifyListeners();
  }

  /// Sets the time at [index]. Returns why not, if it would put the finish
  /// order and the times out of step.
  String? changeTime(int index, Duration time) {
    if (time <= Duration.zero) return 'Enter a time after the start.';
    // Strictly between the places either side: times go to the hundredth,
    // so two finishers never share one, as in the timing conflicts.
    if (index > 0 && time <= _finishes[index - 1].time) {
      return 'Must be after ${ordinal(index)} place '
          '(${TimeFormatter.formatDuration(_finishes[index - 1].time)}).';
    }
    if (index < _finishes.length - 1 && time >= _finishes[index + 1].time) {
      return 'Must be before ${ordinal(index + 2)} place '
          '(${TimeFormatter.formatDuration(_finishes[index + 1].time)}).';
    }
    if (time == _finishes[index].time) return null;
    _change('Time at ${ordinal(index + 1)}');
    _finishes[index] =
        EditableFinish(runner: _finishes[index].runner, time: time);
    notifyListeners();
    return null;
  }

  /// Takes the finish at [index] out of the results, for a disqualification
  /// or someone recorded who did not finish. Everyone after moves up a place.
  void remove(int index) {
    _change('Remove ${_finishes[index].runner.runner.name}');
    _finishes.removeAt(index);
    notifyListeners();
  }

  void undo() {
    if (_history.isEmpty) return;
    _finishes = _history.removeLast().$1;
    notifyListeners();
  }

  /// Saves the results as they now stand. Returns whether they were saved.
  Future<bool> save() async {
    if (_saving) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await _save([
        for (final (i, finish) in _finishes.indexed)
          RaceResult(
            raceId: raceId,
            runner: finish.runner.runner,
            team: finish.runner.team,
            place: i + 1,
            finishTime: finish.time,
          ),
      ]);
      _history.clear();
      return true;
    } catch (e) {
      Logger.e('[EditResultsController.save] $e');
      _error = AppError(
        userMessage: 'Could not save the results. Please try again.',
        originalException: e,
      );
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void _change(String label) => _history.add(([..._finishes], label));

  static int _byBib(RaceRunner a, RaceRunner b) {
    final x = int.tryParse(a.runner.bibNumber ?? '');
    final y = int.tryParse(b.runner.bibNumber ?? '');
    if (x != null && y != null) return x.compareTo(y);
    return (a.runner.bibNumber ?? '').compareTo(b.runner.bibNumber ?? '');
  }
}
