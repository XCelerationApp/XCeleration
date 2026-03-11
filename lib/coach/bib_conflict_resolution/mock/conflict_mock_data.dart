// Mock data models and static dataset for the bib conflict resolution prototype.
// No real database or service calls — all data is in-memory.

/// A runner in the mock "database" who has not yet been assigned a finish position.
class MockRunner {
  const MockRunner({
    required this.bibNumber,
    required this.name,
    required this.team,
    required this.grade,
  });

  final int bibNumber;
  final String name;
  final String team;

  /// Grade year, e.g. 9, 10, 11, 12.
  final int grade;
}

/// A single entry in the finish order (non-conflict).
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
class MockDuplicateConflict extends MockBibConflict {
  const MockDuplicateConflict({
    required this.bibNumber,
    required this.runnerName,
    required this.team,
    required this.grade,
    required this.occurrences,
    required super.surroundingFinishers,
  });

  final int bibNumber;
  final String runnerName;
  final String team;

  /// Grade year, e.g. 9, 10, 11, 12.
  final int grade;

  /// All recorded occurrences of this bib, sorted ascending by finish position.
  final List<({int position, String formattedTime})> occurrences;

  @override
  int get finishPosition => occurrences.first.position;
}

/// A bib number that was entered but matches no runner in the database.
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

/// Static mock dataset. Duplicates come first (by position), then unknowns.
abstract final class ConflictMockData {
  /// Runners in the mock database with no finish position assigned.
  static const List<MockRunner> allUnassignedRunners = [
    MockRunner(bibNumber: 154, name: 'Connor Murphy', team: 'Lincoln HS', grade: 11),
    MockRunner(bibNumber: 155, name: 'Alex Kim', team: 'Lincoln HS', grade: 9),
    MockRunner(bibNumber: 158, name: 'Luke Peterson', team: 'Lincoln HS', grade: 12),
    MockRunner(bibNumber: 200, name: 'Riley Parker', team: 'Westview Academy', grade: 10),
    MockRunner(bibNumber: 201, name: 'Morgan Cooper', team: 'Westview Academy', grade: 11),
    MockRunner(bibNumber: 206, name: 'Peyton Evans', team: 'Westview Academy', grade: 9),
    MockRunner(bibNumber: 305, name: 'Quinn Brooks', team: 'Riverside Prep', grade: 12),
    MockRunner(bibNumber: 307, name: 'Sam Jenkins', team: 'Riverside Prep', grade: 10),
    MockRunner(bibNumber: 311, name: 'Drew Powell', team: 'Riverside Prep', grade: 11),
    MockRunner(bibNumber: 410, name: 'Jordan Scott', team: 'Northgate HS', grade: 9),
    MockRunner(bibNumber: 415, name: 'Tyler Ross', team: 'Northgate HS', grade: 12),
    MockRunner(bibNumber: 421, name: 'Casey Bennett', team: 'Northgate HS', grade: 10),
  ];

  static const List<String> teams = [
    'Lincoln HS',
    'Westview Academy',
    'Riverside Prep',
    'Northgate HS',
  ];

  /// All conflicts ordered: duplicates first (by earliest position), then unknowns.
  static final List<MockBibConflict> conflicts = [
    // --- Duplicate 1: Bib 412 at positions 8 and 12 ---
    const MockDuplicateConflict(
      bibNumber: 412,
      runnerName: 'Marcus Webb',
      team: 'Northgate HS',
      grade: 11,
      occurrences: [
        (position: 8, formattedTime: '16:43'),
        (position: 12, formattedTime: '17:20'),
      ],
      surroundingFinishers: [
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
    const MockDuplicateConflict(
      bibNumber: 410,
      runnerName: 'Jordan Scott',
      team: 'Northgate HS',
      grade: 9,
      occurrences: [
        (position: 10, formattedTime: '17:02'),
        (position: 14, formattedTime: '17:45'),
        (position: 16, formattedTime: '18:09'),
      ],
      surroundingFinishers: [
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
    // --- Duplicate 3: Bib 203 at positions 19 and 22 ---
    const MockDuplicateConflict(
      bibNumber: 203,
      runnerName: 'Finn Holloway',
      team: 'Riverside Prep',
      grade: 10,
      occurrences: [
        (position: 19, formattedTime: '18:44'),
        (position: 22, formattedTime: '19:17'),
      ],
      surroundingFinishers: [
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
