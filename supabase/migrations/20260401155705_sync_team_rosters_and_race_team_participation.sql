-- Add sync columns (uuid, UUID FK refs, updated_at, deleted_at, owner_user_id)
-- to team_rosters and race_team_participation, then enable RLS with per-user
-- ownership policies. These tables were previously pure join tables with no
-- sync support.

-------------------------------------------------------------------------------
-- TEAM_ROSTERS
-------------------------------------------------------------------------------

ALTER TABLE public.team_rosters
  ADD COLUMN IF NOT EXISTS uuid          text,
  ADD COLUMN IF NOT EXISTS team_uuid     text,
  ADD COLUMN IF NOT EXISTS runner_uuid   text,
  ADD COLUMN IF NOT EXISTS owner_user_id uuid,
  ADD COLUMN IF NOT EXISTS updated_at    timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS deleted_at    timestamptz;

-- Unique constraint on uuid for upsert conflict resolution
ALTER TABLE public.team_rosters
  DROP CONSTRAINT IF EXISTS team_rosters_uuid_key;
ALTER TABLE public.team_rosters
  ADD CONSTRAINT team_rosters_uuid_key UNIQUE (uuid);

-- Unique constraint on (team_uuid, runner_uuid) for cross-device upsert
ALTER TABLE public.team_rosters
  DROP CONSTRAINT IF EXISTS team_rosters_team_uuid_runner_uuid_key;
ALTER TABLE public.team_rosters
  ADD CONSTRAINT team_rosters_team_uuid_runner_uuid_key UNIQUE (team_uuid, runner_uuid);

-- Auto-update updated_at on writes
DROP TRIGGER IF EXISTS team_rosters_set_updated_at ON public.team_rosters;
CREATE TRIGGER team_rosters_set_updated_at
BEFORE UPDATE ON public.team_rosters
FOR EACH ROW EXECUTE PROCEDURE trigger_set_timestamp();

-- Backfill UUIDs for existing rows
UPDATE public.team_rosters
SET uuid = gen_random_uuid()::text
WHERE uuid IS NULL;

-- Backfill UUID FK columns from the parent tables
UPDATE public.team_rosters tr
SET team_uuid = t.uuid::text
FROM public.teams t
WHERE tr.team_uuid IS NULL AND tr.team_id = t.team_id;

UPDATE public.team_rosters tr
SET runner_uuid = r.uuid::text
FROM public.runners r
WHERE tr.runner_uuid IS NULL AND tr.runner_id = r.runner_id;

-- Backfill owner_user_id from parent team
UPDATE public.team_rosters tr
SET owner_user_id = t.owner_user_id
FROM public.teams t
WHERE tr.owner_user_id IS NULL AND tr.team_id = t.team_id;

-- Index for cursor-based pull
CREATE INDEX IF NOT EXISTS idx_team_rosters_updated_at ON public.team_rosters(updated_at);
CREATE INDEX IF NOT EXISTS idx_team_rosters_owner ON public.team_rosters(owner_user_id);

-- Enable RLS
ALTER TABLE public.team_rosters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tr_select_own ON public.team_rosters;
DROP POLICY IF EXISTS tr_insert_own ON public.team_rosters;
DROP POLICY IF EXISTS tr_update_own ON public.team_rosters;
DROP POLICY IF EXISTS tr_delete_own ON public.team_rosters;

CREATE POLICY tr_select_own ON public.team_rosters FOR SELECT USING (owner_user_id = auth.uid());
CREATE POLICY tr_insert_own ON public.team_rosters FOR INSERT WITH CHECK (owner_user_id = auth.uid());
CREATE POLICY tr_update_own ON public.team_rosters FOR UPDATE USING (owner_user_id = auth.uid()) WITH CHECK (owner_user_id = auth.uid());
CREATE POLICY tr_delete_own ON public.team_rosters FOR DELETE USING (owner_user_id = auth.uid());

-------------------------------------------------------------------------------
-- RACE_TEAM_PARTICIPATION
-------------------------------------------------------------------------------

ALTER TABLE public.race_team_participation
  ADD COLUMN IF NOT EXISTS uuid          text,
  ADD COLUMN IF NOT EXISTS race_uuid     text,
  ADD COLUMN IF NOT EXISTS team_uuid     text,
  ADD COLUMN IF NOT EXISTS owner_user_id uuid,
  ADD COLUMN IF NOT EXISTS updated_at    timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS deleted_at    timestamptz;

-- Unique constraint on uuid for upsert conflict resolution
ALTER TABLE public.race_team_participation
  DROP CONSTRAINT IF EXISTS race_team_participation_uuid_key;
ALTER TABLE public.race_team_participation
  ADD CONSTRAINT race_team_participation_uuid_key UNIQUE (uuid);

-- Unique constraint on (race_uuid, team_uuid) for cross-device upsert
ALTER TABLE public.race_team_participation
  DROP CONSTRAINT IF EXISTS race_team_participation_race_uuid_team_uuid_key;
ALTER TABLE public.race_team_participation
  ADD CONSTRAINT race_team_participation_race_uuid_team_uuid_key UNIQUE (race_uuid, team_uuid);

-- Auto-update updated_at on writes
DROP TRIGGER IF EXISTS race_team_participation_set_updated_at ON public.race_team_participation;
CREATE TRIGGER race_team_participation_set_updated_at
BEFORE UPDATE ON public.race_team_participation
FOR EACH ROW EXECUTE PROCEDURE trigger_set_timestamp();

-- Backfill UUIDs for existing rows
UPDATE public.race_team_participation
SET uuid = gen_random_uuid()::text
WHERE uuid IS NULL;

-- Backfill UUID FK columns from the parent tables
UPDATE public.race_team_participation rtp
SET race_uuid = r.uuid::text
FROM public.races r
WHERE rtp.race_uuid IS NULL AND rtp.race_id = r.race_id;

UPDATE public.race_team_participation rtp
SET team_uuid = t.uuid::text
FROM public.teams t
WHERE rtp.team_uuid IS NULL AND rtp.team_id = t.team_id;

-- Backfill owner_user_id from parent race
UPDATE public.race_team_participation rtp
SET owner_user_id = r.owner_user_id
FROM public.races r
WHERE rtp.owner_user_id IS NULL AND rtp.race_id = r.race_id;

-- Index for cursor-based pull
CREATE INDEX IF NOT EXISTS idx_race_team_participation_updated_at ON public.race_team_participation(updated_at);
CREATE INDEX IF NOT EXISTS idx_race_team_participation_owner ON public.race_team_participation(owner_user_id);

-- Enable RLS
ALTER TABLE public.race_team_participation ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rtp_select_own ON public.race_team_participation;
DROP POLICY IF EXISTS rtp_insert_own ON public.race_team_participation;
DROP POLICY IF EXISTS rtp_update_own ON public.race_team_participation;
DROP POLICY IF EXISTS rtp_delete_own ON public.race_team_participation;

CREATE POLICY rtp_select_own ON public.race_team_participation FOR SELECT USING (owner_user_id = auth.uid());
CREATE POLICY rtp_insert_own ON public.race_team_participation FOR INSERT WITH CHECK (owner_user_id = auth.uid());
CREATE POLICY rtp_update_own ON public.race_team_participation FOR UPDATE USING (owner_user_id = auth.uid()) WITH CHECK (owner_user_id = auth.uid());
CREATE POLICY rtp_delete_own ON public.race_team_participation FOR DELETE USING (owner_user_id = auth.uid());
