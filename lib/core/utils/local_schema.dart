/// Centralized local SQLite schema used by DatabaseHelper.onCreate
/// This mirrors the remote schema where reasonable and adds local-only
/// columns for offline sync (is_dirty) and timestamps on join tables.
const String localSchemaSql = r'''
-- 1. RUNNERS
CREATE TABLE IF NOT EXISTS runners (
  runner_id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE,
  name TEXT NOT NULL CHECK(length(name) > 0),
  grade INTEGER CHECK(grade >= 9 AND grade <= 12),
  bib_number TEXT UNIQUE NOT NULL CHECK(length(bib_number) > 0),
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT,
  is_dirty INTEGER NOT NULL DEFAULT 0
);

-- 2. TEAMS
CREATE TABLE IF NOT EXISTS teams (
  team_id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE,
  name TEXT NOT NULL CHECK(length(name) > 0),
  abbreviation TEXT CHECK(length(abbreviation) <= 3),
  color INTEGER NOT NULL DEFAULT 0,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT,
  is_dirty INTEGER NOT NULL DEFAULT 0,
  UNIQUE (name)
);

-- 3. TEAM_ROSTERS (local adds timestamps + is_dirty)
CREATE TABLE IF NOT EXISTS team_rosters (
  team_id INTEGER NOT NULL,
  runner_id INTEGER NOT NULL,
  joined_date TEXT DEFAULT CURRENT_TIMESTAMP,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT,
  is_dirty INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (team_id, runner_id),
  FOREIGN KEY (team_id) REFERENCES teams(team_id) ON DELETE CASCADE,
  FOREIGN KEY (runner_id) REFERENCES runners(runner_id) ON DELETE CASCADE
);

-- 4. RACE_TEAM_PARTICIPATION (local adds timestamps + is_dirty)
CREATE TABLE IF NOT EXISTS race_team_participation (
  race_id INTEGER NOT NULL,
  team_id INTEGER NOT NULL,
  team_color_override INTEGER,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT,
  is_dirty INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (race_id, team_id),
  FOREIGN KEY (race_id) REFERENCES races(race_id) ON DELETE CASCADE,
  FOREIGN KEY (team_id) REFERENCES teams(team_id) ON DELETE CASCADE
);

-- 5. RACE_PARTICIPANTS
CREATE TABLE IF NOT EXISTS race_participants (
  race_id INTEGER NOT NULL,
  runner_id INTEGER NOT NULL,
  team_id INTEGER NOT NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT,
  is_dirty INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (race_id, runner_id),
  FOREIGN KEY (race_id) REFERENCES races(race_id) ON DELETE CASCADE,
  FOREIGN KEY (runner_id) REFERENCES runners(runner_id) ON DELETE CASCADE,
  FOREIGN KEY (team_id) REFERENCES teams(team_id) ON DELETE CASCADE
);

-- 6. RACES
CREATE TABLE IF NOT EXISTS races (
  race_id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE,
  owner_user_id TEXT,
  name TEXT NOT NULL CHECK(length(name) > 0),
  race_date TEXT DEFAULT '',
  location TEXT DEFAULT '',
  distance REAL DEFAULT 0,
  distance_unit TEXT DEFAULT 'mi',
  flow_state TEXT DEFAULT 'setup',
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT,
  is_dirty INTEGER NOT NULL DEFAULT 0
);

-- 7. RACE_RESULTS
CREATE TABLE IF NOT EXISTS race_results (
  result_id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE,
  race_id INTEGER NOT NULL,
  runner_id INTEGER NOT NULL,
  team_id INTEGER,  -- Added team_id column
  place INTEGER,
  finish_time INTEGER,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT,
  is_dirty INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (race_id) REFERENCES races(race_id) ON DELETE CASCADE,
  FOREIGN KEY (runner_id) REFERENCES runners(runner_id) ON DELETE CASCADE,
  FOREIGN KEY (team_id) REFERENCES teams(team_id) ON DELETE CASCADE,
  UNIQUE (race_id, runner_id),
  UNIQUE (race_id, place)
);

-- 8. SYNC STATE (no is_dirty; internal key-value store)
CREATE TABLE IF NOT EXISTS sync_state (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_runners_name_grade ON runners(name, grade);
CREATE INDEX IF NOT EXISTS idx_runners_name ON runners(name);
CREATE INDEX IF NOT EXISTS idx_runners_bib ON runners(bib_number);

CREATE INDEX IF NOT EXISTS idx_teams_name ON teams(name);
CREATE INDEX IF NOT EXISTS idx_teams_abbreviation ON teams(abbreviation);

CREATE INDEX IF NOT EXISTS idx_team_rosters_team ON team_rosters(team_id);
CREATE INDEX IF NOT EXISTS idx_team_rosters_runner ON team_rosters(runner_id);

CREATE INDEX IF NOT EXISTS idx_race_team_participation_race ON race_team_participation(race_id);

CREATE INDEX IF NOT EXISTS idx_race_participants_race ON race_participants(race_id);
CREATE INDEX IF NOT EXISTS idx_race_participants_team ON race_participants(team_id);

CREATE INDEX IF NOT EXISTS idx_races_date ON races(race_date);

CREATE INDEX IF NOT EXISTS idx_race_results_race ON race_results(race_id);
CREATE INDEX IF NOT EXISTS idx_race_results_place ON race_results(race_id, place);
''';

/// Utility to split and execute the schema script safely
/// - Strips out single-line comments starting with '--'
/// - Splits on semicolons
List<String> splitSqlStatements(String script) {
  final buffer = StringBuffer();
  for (final line in script.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('--')) {
      continue; // drop SQL comment lines entirely
    }
    buffer.writeln(line);
  }
  final cleaned = buffer.toString();
  return cleaned
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}
