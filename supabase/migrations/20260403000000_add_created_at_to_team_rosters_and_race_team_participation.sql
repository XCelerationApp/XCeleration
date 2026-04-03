-- Add missing created_at column to team_rosters and race_team_participation.
-- The local SQLite schema has always included created_at; this migration brings
-- the remote Postgres schema into alignment so push payloads no longer send an
-- unknown column.

ALTER TABLE public.team_rosters
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.race_team_participation
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();
