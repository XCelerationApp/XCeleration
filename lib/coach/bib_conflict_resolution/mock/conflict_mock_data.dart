// Mock data models and static dataset for the bib conflict resolution prototype.
// No real database or service calls — all data is in-memory.
//
// Input types mirror what LoadResultsController produces:
//   • unassigned runners are List<RaceRunner> (the real DB type)
//   • duplicate conflicts carry a RaceRunner for the known runner
//   • unknown conflicts carry an int bib (matches the int sentinel in raceRunners)
//
// Output: ConflictResolutionController.resolvedRunners returns List<RaceRunner>,
// matching the List<RaceRunner> expected by BibConflictsOverview.onResolved.

import 'package:flutter/material.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

export 'package:xceleration/shared/models/database/race_runner.dart';

/// A single entry in the finish order (non-conflict), used for context display.
class MockFinishEntry {
  const MockFinishEntry({
    required this.position,
    required this.bibNumber,
    required this.formattedTime,
    required this.runnerName,
    required this.team,
  });

  final int position;
  final int bibNumber;
  final String formattedTime;
  final String runnerName;
  final String team;
}

/// Base class for all conflict types.
sealed class MockBibConflict {
  const MockBibConflict({required this.surroundingFinishers});

  /// Non-conflict finishers surrounding this conflict's position(s).
  /// Sorted ascending by finish position.
  final List<MockFinishEntry> surroundingFinishers;

  /// The earliest finish position involved in this conflict.
  int get finishPosition;
}

/// A bib number that appears at multiple different finish positions.
/// [raceRunner] is the registered runner who owns this bib — the real [RaceRunner]
/// type from the database, matching what [LoadResultsController] resolves.
class MockDuplicateConflict extends MockBibConflict {
  MockDuplicateConflict({
    required this.raceRunner,
    required this.occurrences,
    required super.surroundingFinishers,
  });

  /// The registered runner whose bib was recorded multiple times.
  final RaceRunner raceRunner;

  /// All recorded occurrences of this bib, sorted ascending by finish position.
  final List<({int position, String formattedTime})> occurrences;

  // Computed accessors so widget code can reference conflict.bibNumber etc.
  int get bibNumber => int.parse(raceRunner.runner.bibNumber ?? '0');
  String get runnerName => raceRunner.runner.name ?? '';
  String get team => raceRunner.team.name ?? '';
  int get grade => raceRunner.runner.grade ?? 0;

  @override
  int get finishPosition => occurrences.first.position;
}

/// A bib number that was entered but matches no runner in the database.
/// [enteredBib] is an int, matching the int sentinel that [LoadResultsController]
/// stores in raceRunners for unresolvable bibs.
class MockUnknownConflict extends MockBibConflict {
  const MockUnknownConflict({
    required this.enteredBib,
    required this.position,
    required this.formattedTime,
    required super.surroundingFinishers,
  });

  final int enteredBib;
  final int position;
  final String formattedTime;

  @override
  int get finishPosition => position;
}

// ---------------------------------------------------------------------------
// Team constants used across the mock dataset.
// ---------------------------------------------------------------------------

final _lincolnHS = Team(
  teamId: 1,
  name: 'Lincoln HS',
  abbreviation: 'LHS',
  color: const Color(0xFF1565C0),
);
final _westview = Team(
  teamId: 2,
  name: 'Westview Academy',
  abbreviation: 'WVA',
  color: const Color(0xFF2E7D32),
);
final _riverside = Team(
  teamId: 3,
  name: 'Riverside Prep',
  abbreviation: 'RVP',
  color: const Color(0xFFE65100),
);
final _northgate = Team(
  teamId: 4,
  name: 'Northgate HS',
  abbreviation: 'NGH',
  color: const Color(0xFF6A1B9A),
);

/// Static mock dataset. Duplicates come first (by position), then unknowns.
abstract final class ConflictMockData {
  static const int raceId = 1;

  /// Runners registered for this race who have not yet been assigned a finish
  /// position. Typed as [RaceRunner] to match the real unassigned-runner pool
  /// that [ConflictResolutionController] receives.
  static final List<RaceRunner> allUnassignedRunners = [
    RaceRunner(raceId: raceId, runner: Runner(runnerId: 1, bibNumber: '154', name: 'Connor Murphy', grade: 11), team: _lincolnHS),
    RaceRunner(raceId: raceId, runner: Runner(runnerId: 2, bibNumber: '155', name: 'Alex Kim', grade: 9), team: _lincolnHS),
    RaceRunner(raceId: raceId, runner: Runner(runnerId: 3, bibNumber: '158', name: 'Luke Peterson', grade: 12), team: _lincolnHS),
    RaceRunner(raceId: raceId, runner: Runner(runnerId: 4, bibNumber: '200', name: 'Riley Parker', grade: 10), team: _westview),
    RaceRunner(raceId: raceId, runner: Runner(runnerId: 5, bibNumber: '201', name: 'Morgan Cooper', grade: 11), team: _westview),
    RaceRunner(raceId: raceId, runner: Runner(runnerId: 6, bibNumber: '206', name: 'Peyton Evans', grade: 9), team: _westview),
    RaceRunner(raceId: raceId, runner: Runner(runnerId: 7, bibNumber: '305', name: 'Quinn Brooks', grade: 12), team: _riverside),
    RaceRunner(raceId: raceId, runner: Runner(runnerId: 8, bibNumber: '307', name: 'Sam Jenkins', grade: 10), team: _riverside),
    RaceRunner(raceId: raceId, runner: Runner(runnerId: 9, bibNumber: '311', name: 'Drew Powell', grade: 11), team: _riverside),
    RaceRunner(raceId: raceId, runner: Runner(runnerId: 10, bibNumber: '410', name: 'Jordan Scott', grade: 9), team: _northgate),
    RaceRunner(raceId: raceId, runner: Runner(runnerId: 11, bibNumber: '415', name: 'Tyler Ross', grade: 12), team: _northgate),
    RaceRunner(raceId: raceId, runner: Runner(runnerId: 12, bibNumber: '421', name: 'Casey Bennett', grade: 10), team: _northgate),
  ];

  /// All conflicts ordered: duplicates first (by earliest position), then unknowns.
  static final List<MockBibConflict> conflicts = [
    // --- Duplicate 1: Bib 412 at positions 8 and 12 ---
    MockDuplicateConflict(
      raceRunner: RaceRunner(
        raceId: raceId,
        runner: Runner(runnerId: 13, bibNumber: '412', name: 'Marcus Webb', grade: 11),
        team: _northgate,
      ),
      occurrences: [
        (position: 8, formattedTime: '16:43'),
        (position: 12, formattedTime: '17:20'),
      ],
      surroundingFinishers: const [
        MockFinishEntry(position: 3, bibNumber: 314, formattedTime: '15:52', runnerName: 'Noah Garcia', team: 'Riverside Prep'),
        MockFinishEntry(position: 4, bibNumber: 178, formattedTime: '16:01', runnerName: 'Ethan Martinez', team: 'Lincoln HS'),
        MockFinishEntry(position: 5, bibNumber: 423, formattedTime: '16:14', runnerName: 'Liam Johnson', team: 'Northgate HS'),
        MockFinishEntry(position: 6, bibNumber: 205, formattedTime: '16:22', runnerName: 'Henry Brown', team: 'Westview Academy'),
        MockFinishEntry(position: 7, bibNumber: 312, formattedTime: '16:31', runnerName: 'Mason Davis', team: 'Riverside Prep'),
        MockFinishEntry(position: 9, bibNumber: 117, formattedTime: '16:55', runnerName: 'Oliver Wilson', team: 'Lincoln HS'),
        MockFinishEntry(position: 10, bibNumber: 334, formattedTime: '17:02', runnerName: 'William Taylor', team: 'Riverside Prep'),
        MockFinishEntry(position: 11, bibNumber: 289, formattedTime: '17:11', runnerName: 'Benjamin Anderson', team: 'Westview Academy'),
        MockFinishEntry(position: 13, bibNumber: 222, formattedTime: '17:31', runnerName: 'Lucas Jackson', team: 'Westview Academy'),
        MockFinishEntry(position: 14, bibNumber: 388, formattedTime: '17:45', runnerName: 'Logan White', team: 'Riverside Prep'),
        MockFinishEntry(position: 15, bibNumber: 255, formattedTime: '17:58', runnerName: 'Owen Harris', team: 'Westview Academy'),
      ],
    ),
    // --- Duplicate 2: Bib 410 at positions 10, 14, and 16 (3 occurrences) ---
    MockDuplicateConflict(
      raceRunner: RaceRunner(
        raceId: raceId,
        runner: Runner(runnerId: 10, bibNumber: '410', name: 'Jordan Scott', grade: 9),
        team: _northgate,
      ),
      occurrences: [
        (position: 10, formattedTime: '17:02'),
        (position: 14, formattedTime: '17:45'),
        (position: 16, formattedTime: '18:09'),
      ],
      surroundingFinishers: const [
        MockFinishEntry(position: 6, bibNumber: 205, formattedTime: '16:22', runnerName: 'Henry Brown', team: 'Westview Academy'),
        MockFinishEntry(position: 7, bibNumber: 312, formattedTime: '16:31', runnerName: 'Mason Davis', team: 'Riverside Prep'),
        MockFinishEntry(position: 8, bibNumber: 412, formattedTime: '16:43', runnerName: 'Marcus Webb', team: 'Northgate HS'),
        MockFinishEntry(position: 9, bibNumber: 117, formattedTime: '16:55', runnerName: 'Oliver Wilson', team: 'Lincoln HS'),
        MockFinishEntry(position: 11, bibNumber: 289, formattedTime: '17:11', runnerName: 'Benjamin Anderson', team: 'Westview Academy'),
        MockFinishEntry(position: 12, bibNumber: 367, formattedTime: '17:24', runnerName: 'James Nguyen', team: 'Riverside Prep'),
        MockFinishEntry(position: 13, bibNumber: 445, formattedTime: '17:36', runnerName: 'Tyler Brooks', team: 'Westview Academy'),
        MockFinishEntry(position: 15, bibNumber: 255, formattedTime: '17:58', runnerName: 'Owen Harris', team: 'Westview Academy'),
        MockFinishEntry(position: 17, bibNumber: 190, formattedTime: '18:21', runnerName: 'Carter Thompson', team: 'Lincoln HS'),
        MockFinishEntry(position: 18, bibNumber: 327, formattedTime: '18:33', runnerName: 'Dylan Garcia', team: 'Riverside Prep'),
      ],
    ),
    // --- Duplicate 3: Bib 415 at positions 31, 35, and 39 (3 occurrences) ---
    MockDuplicateConflict(
      raceRunner: RaceRunner(
        raceId: raceId,
        runner: Runner(runnerId: 11, bibNumber: '415', name: 'Tyler Ross', grade: 12),
        team: _northgate,
      ),
      occurrences: [
        (position: 31, formattedTime: '21:07'),
        (position: 35, formattedTime: '21:44'),
        (position: 39, formattedTime: '22:18'),
      ],
      surroundingFinishers: const [
        MockFinishEntry(position: 27, bibNumber: 247, formattedTime: '20:12', runnerName: 'Gabriel Walker', team: 'Westview Academy'),
        MockFinishEntry(position: 28, bibNumber: 308, formattedTime: '20:34', runnerName: 'Christian Hall', team: 'Riverside Prep'),
        MockFinishEntry(position: 29, bibNumber: 371, formattedTime: '20:45', runnerName: 'Eli Allen', team: 'Lincoln HS'),
        MockFinishEntry(position: 30, bibNumber: 192, formattedTime: '20:56', runnerName: 'Aaron Young', team: 'Riverside Prep'),
        MockFinishEntry(position: 32, bibNumber: 263, formattedTime: '21:18', runnerName: 'Caleb Moore', team: 'Westview Academy'),
        MockFinishEntry(position: 33, bibNumber: 347, formattedTime: '21:27', runnerName: 'Isaiah Thomas', team: 'Lincoln HS'),
        MockFinishEntry(position: 34, bibNumber: 408, formattedTime: '21:36', runnerName: 'Dominic Hall', team: 'Northgate HS'),
        MockFinishEntry(position: 36, bibNumber: 181, formattedTime: '21:52', runnerName: 'Zachary Turner', team: 'Riverside Prep'),
        MockFinishEntry(position: 37, bibNumber: 319, formattedTime: '22:01', runnerName: 'Miles King', team: 'Westview Academy'),
        MockFinishEntry(position: 38, bibNumber: 452, formattedTime: '22:09', runnerName: 'Nolan Green', team: 'Lincoln HS'),
        MockFinishEntry(position: 40, bibNumber: 176, formattedTime: '22:27', runnerName: 'Preston Scott', team: 'Northgate HS'),
      ],
    ),
    // --- Duplicate 4: Bib 203 at positions 19 and 22 ---
    MockDuplicateConflict(
      raceRunner: RaceRunner(
        raceId: raceId,
        runner: Runner(runnerId: 14, bibNumber: '203', name: 'Finn Holloway', grade: 10),
        team: _riverside,
      ),
      occurrences: [
        (position: 19, formattedTime: '18:44'),
        (position: 22, formattedTime: '19:17'),
      ],
      surroundingFinishers: const [
        MockFinishEntry(position: 14, bibNumber: 388, formattedTime: '17:45', runnerName: 'Logan White', team: 'Riverside Prep'),
        MockFinishEntry(position: 15, bibNumber: 255, formattedTime: '17:58', runnerName: 'Owen Harris', team: 'Westview Academy'),
        MockFinishEntry(position: 16, bibNumber: 461, formattedTime: '18:09', runnerName: 'Aiden Martin', team: 'Northgate HS'),
        MockFinishEntry(position: 17, bibNumber: 190, formattedTime: '18:21', runnerName: 'Carter Thompson', team: 'Lincoln HS'),
        MockFinishEntry(position: 18, bibNumber: 327, formattedTime: '18:33', runnerName: 'Dylan Garcia', team: 'Riverside Prep'),
        MockFinishEntry(position: 20, bibNumber: 444, formattedTime: '18:55', runnerName: 'Jayden Martinez', team: 'Northgate HS'),
        MockFinishEntry(position: 21, bibNumber: 139, formattedTime: '19:06', runnerName: 'Sebastian Robinson', team: 'Lincoln HS'),
        MockFinishEntry(position: 23, bibNumber: 275, formattedTime: '19:28', runnerName: 'Jack Clark', team: 'Westview Academy'),
        MockFinishEntry(position: 24, bibNumber: 358, formattedTime: '19:39', runnerName: 'Wyatt Rodriguez', team: 'Riverside Prep'),
        MockFinishEntry(position: 25, bibNumber: 413, formattedTime: '19:50', runnerName: 'Nathan Lewis', team: 'Northgate HS'),
      ],
    ),
    // --- Unknown 1: Bib 156 at position 3 (not in database) ---
    const MockUnknownConflict(
      enteredBib: 156,
      position: 3,
      formattedTime: '15:52',
      surroundingFinishers: [
        MockFinishEntry(position: 1, bibNumber: 101, formattedTime: '15:23', runnerName: 'James Carter', team: 'Lincoln HS'),
        MockFinishEntry(position: 2, bibNumber: 202, formattedTime: '15:45', runnerName: 'Ryan Lee', team: 'Westview Academy'),
        MockFinishEntry(position: 4, bibNumber: 178, formattedTime: '16:01', runnerName: 'Ethan Martinez', team: 'Lincoln HS'),
        MockFinishEntry(position: 5, bibNumber: 423, formattedTime: '16:14', runnerName: 'Liam Johnson', team: 'Northgate HS'),
        MockFinishEntry(position: 6, bibNumber: 205, formattedTime: '16:22', runnerName: 'Henry Brown', team: 'Westview Academy'),
        MockFinishEntry(position: 7, bibNumber: 312, formattedTime: '16:31', runnerName: 'Mason Davis', team: 'Riverside Prep'),
      ],
    ),
    // --- Unknown 2: Bib 308 at position 28 (not in database) ---
    const MockUnknownConflict(
      enteredBib: 308,
      position: 28,
      formattedTime: '20:34',
      surroundingFinishers: [
        MockFinishEntry(position: 23, bibNumber: 275, formattedTime: '19:28', runnerName: 'Jack Clark', team: 'Westview Academy'),
        MockFinishEntry(position: 24, bibNumber: 358, formattedTime: '19:39', runnerName: 'Wyatt Rodriguez', team: 'Riverside Prep'),
        MockFinishEntry(position: 25, bibNumber: 413, formattedTime: '19:50', runnerName: 'Nathan Lewis', team: 'Northgate HS'),
        MockFinishEntry(position: 26, bibNumber: 166, formattedTime: '20:01', runnerName: 'Isaac Lee', team: 'Lincoln HS'),
        MockFinishEntry(position: 27, bibNumber: 247, formattedTime: '20:12', runnerName: 'Gabriel Walker', team: 'Westview Academy'),
        MockFinishEntry(position: 29, bibNumber: 371, formattedTime: '20:45', runnerName: 'Christian Hall', team: 'Riverside Prep'),
        MockFinishEntry(position: 30, bibNumber: 192, formattedTime: '20:56', runnerName: 'Eli Allen', team: 'Lincoln HS'),
        MockFinishEntry(position: 31, bibNumber: 329, formattedTime: '21:07', runnerName: 'Aaron Young', team: 'Riverside Prep'),
      ],
    ),
  ];
}
