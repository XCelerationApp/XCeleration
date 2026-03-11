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
  });

  final int position;
  final int bibNumber;
  final String formattedTime;
  final String runnerName;
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

/// A bib number that appears at two different finish positions.
class MockDuplicateConflict extends MockBibConflict {
  const MockDuplicateConflict({
    required this.bibNumber,
    required this.runnerName,
    required this.team,
    required this.grade,
    required this.entry1,
    required this.entry2,
    required super.surroundingFinishers,
  });

  final int bibNumber;
  final String runnerName;
  final String team;

  /// Grade year, e.g. 9, 10, 11, 12.
  final int grade;

  /// The first (earlier) occurrence.
  final ({int position, String formattedTime}) entry1;

  /// The second (later) occurrence.
  final ({int position, String formattedTime}) entry2;

  @override
  int get finishPosition => entry1.position;
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

  /// All conflicts ordered: duplicates first (by position), then unknowns.
  static final List<MockBibConflict> conflicts = [
    // --- Duplicate 1: Bib 412 at positions 8 and 12 ---
    const MockDuplicateConflict(
      bibNumber: 412,
      runnerName: 'Marcus Webb',
      team: 'Northgate HS',
      grade: 11,
      entry1: (position: 8, formattedTime: '16:43'),
      entry2: (position: 12, formattedTime: '17:20'),
      surroundingFinishers: [
        MockFinishEntry(position: 3, bibNumber: 314, formattedTime: '15:52', runnerName: 'Noah Garcia'),
        MockFinishEntry(position: 4, bibNumber: 178, formattedTime: '16:01', runnerName: 'Ethan Martinez'),
        MockFinishEntry(position: 5, bibNumber: 423, formattedTime: '16:14', runnerName: 'Liam Johnson'),
        MockFinishEntry(position: 6, bibNumber: 205, formattedTime: '16:22', runnerName: 'Henry Brown'),
        MockFinishEntry(position: 7, bibNumber: 312, formattedTime: '16:31', runnerName: 'Mason Davis'),
        MockFinishEntry(position: 9, bibNumber: 117, formattedTime: '16:55', runnerName: 'Oliver Wilson'),
        MockFinishEntry(position: 10, bibNumber: 334, formattedTime: '17:02', runnerName: 'William Taylor'),
        MockFinishEntry(position: 11, bibNumber: 289, formattedTime: '17:11', runnerName: 'Benjamin Anderson'),
        MockFinishEntry(position: 13, bibNumber: 222, formattedTime: '17:31', runnerName: 'Lucas Jackson'),
        MockFinishEntry(position: 14, bibNumber: 388, formattedTime: '17:45', runnerName: 'Logan White'),
        MockFinishEntry(position: 15, bibNumber: 255, formattedTime: '17:58', runnerName: 'Owen Harris'),
      ],
    ),
    // --- Duplicate 2: Bib 203 at positions 19 and 22 ---
    const MockDuplicateConflict(
      bibNumber: 203,
      runnerName: 'Finn Holloway',
      team: 'Riverside Prep',
      grade: 10,
      entry1: (position: 19, formattedTime: '18:44'),
      entry2: (position: 22, formattedTime: '19:17'),
      surroundingFinishers: [
        MockFinishEntry(position: 14, bibNumber: 388, formattedTime: '17:45', runnerName: 'Logan White'),
        MockFinishEntry(position: 15, bibNumber: 255, formattedTime: '17:58', runnerName: 'Owen Harris'),
        MockFinishEntry(position: 16, bibNumber: 461, formattedTime: '18:09', runnerName: 'Aiden Martin'),
        MockFinishEntry(position: 17, bibNumber: 190, formattedTime: '18:21', runnerName: 'Carter Thompson'),
        MockFinishEntry(position: 18, bibNumber: 327, formattedTime: '18:33', runnerName: 'Dylan Garcia'),
        MockFinishEntry(position: 20, bibNumber: 444, formattedTime: '18:55', runnerName: 'Jayden Martinez'),
        MockFinishEntry(position: 21, bibNumber: 139, formattedTime: '19:06', runnerName: 'Sebastian Robinson'),
        MockFinishEntry(position: 23, bibNumber: 275, formattedTime: '19:28', runnerName: 'Jack Clark'),
        MockFinishEntry(position: 24, bibNumber: 358, formattedTime: '19:39', runnerName: 'Wyatt Rodriguez'),
        MockFinishEntry(position: 25, bibNumber: 413, formattedTime: '19:50', runnerName: 'Nathan Lewis'),
      ],
    ),
    // --- Unknown 1: Bib 156 at position 3 (not in database) ---
    const MockUnknownConflict(
      enteredBib: 156,
      position: 3,
      formattedTime: '15:52',
      surroundingFinishers: [
        MockFinishEntry(position: 1, bibNumber: 101, formattedTime: '15:23', runnerName: 'James Carter'),
        MockFinishEntry(position: 2, bibNumber: 202, formattedTime: '15:45', runnerName: 'Ryan Lee'),
        MockFinishEntry(position: 4, bibNumber: 178, formattedTime: '16:01', runnerName: 'Ethan Martinez'),
        MockFinishEntry(position: 5, bibNumber: 423, formattedTime: '16:14', runnerName: 'Liam Johnson'),
        MockFinishEntry(position: 6, bibNumber: 205, formattedTime: '16:22', runnerName: 'Henry Brown'),
        MockFinishEntry(position: 7, bibNumber: 312, formattedTime: '16:31', runnerName: 'Mason Davis'),
      ],
    ),
    // --- Unknown 2: Bib 308 at position 28 (not in database) ---
    const MockUnknownConflict(
      enteredBib: 308,
      position: 28,
      formattedTime: '20:34',
      surroundingFinishers: [
        MockFinishEntry(position: 23, bibNumber: 275, formattedTime: '19:28', runnerName: 'Jack Clark'),
        MockFinishEntry(position: 24, bibNumber: 358, formattedTime: '19:39', runnerName: 'Wyatt Rodriguez'),
        MockFinishEntry(position: 25, bibNumber: 413, formattedTime: '19:50', runnerName: 'Nathan Lewis'),
        MockFinishEntry(position: 26, bibNumber: 166, formattedTime: '20:01', runnerName: 'Isaac Lee'),
        MockFinishEntry(position: 27, bibNumber: 247, formattedTime: '20:12', runnerName: 'Gabriel Walker'),
        MockFinishEntry(position: 29, bibNumber: 371, formattedTime: '20:45', runnerName: 'Christian Hall'),
        MockFinishEntry(position: 30, bibNumber: 192, formattedTime: '20:56', runnerName: 'Eli Allen'),
        MockFinishEntry(position: 31, bibNumber: 329, formattedTime: '21:07', runnerName: 'Aaron Young'),
      ],
    ),
  ];
}
