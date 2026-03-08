-- Migration: UUID-based sync for race_results and race_participants
-- Companion to local DB migrations v17 and v18.
--
-- Why:
--   The app now pushes race_results using runner_uuid/race_uuid as the
--   identity keys (not integer runner_id/race_id) so that results are
--   meaningful across devices. race_participants is rebuilt with the same
--   UUID-based primary key that the app upserts on.
--
-- Apply in: Supabase SQL editor (run as one transaction).

begin;

-- ================================================================
-- 1. RACE_RESULTS
--    - Add UUID FK columns and owner_user_id
--    - Make integer FK columns nullable (app no longer sends them)
--    - Drop integer FK constraints and integer-pair unique constraints
--    - Promote uuid to primary key (was a unique column; result_id was PK)
--    - Add unique constraint on (race_uuid, runner_uuid)
--    - Update RLS to check owner_user_id directly
-- ================================================================

-- Add new columns (idempotent with IF NOT EXISTS)
alter table public.race_results
  add column if not exists runner_uuid   text,
  add column if not exists race_uuid     text,
  add column if not exists owner_user_id uuid,
  add column if not exists team_id       bigint;

-- Make old FK columns nullable — the app strips them from push payloads
alter table public.race_results
  alter column race_id   drop not null,
  alter column runner_id drop not null;

-- Drop old FK constraints
alter table public.race_results
  drop constraint if exists race_results_race_id_fkey,
  drop constraint if exists race_results_runner_id_fkey;

-- Drop integer-pair unique constraints
alter table public.race_results
  drop constraint if exists race_results_race_id_runner_id_key,
  drop constraint if exists race_results_race_id_place_key;

-- Promote uuid to primary key
-- (result_id bigserial remains but is no longer the PK;
--  the app strips it on push and ignores it on pull)
alter table public.race_results drop constraint if exists race_results_pkey;
alter table public.race_results add primary key (uuid);

-- One result per runner per race (UUID-based)
alter table public.race_results
  add constraint race_results_race_uuid_runner_uuid_key unique (race_uuid, runner_uuid);

-- Indexes for pull queries
create index if not exists idx_race_results_owner     on public.race_results(owner_user_id);
create index if not exists idx_race_results_race_uuid on public.race_results(race_uuid);

-- Replace RLS policies (old ones joined on integer race_id which is now nullable)
drop policy if exists rr_select_own on public.race_results;
drop policy if exists rr_modify_own on public.race_results;
drop policy if exists rr_update_own on public.race_results;
drop policy if exists rr_delete_own on public.race_results;

alter table public.race_results enable row level security;

create policy rr_select_own on public.race_results
  for select using (owner_user_id = auth.uid());
create policy rr_modify_own on public.race_results
  for insert with check (owner_user_id = auth.uid());
create policy rr_update_own on public.race_results
  for update using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());
create policy rr_delete_own on public.race_results
  for delete using (owner_user_id = auth.uid());

-- ================================================================
-- 2. RACE_PARTICIPANTS
--    - Drop and recreate with UUID-based primary key and sync columns.
--    - Old table had integer FK PK (race_id, runner_id); the app now
--      upserts on (race_uuid, runner_uuid) and sends no integer FKs.
-- ================================================================

drop table if exists public.race_participants;

create table public.race_participants (
  race_uuid     text        not null,
  runner_uuid   text        not null,
  team_uuid     text,
  owner_user_id uuid        not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  primary key (race_uuid, runner_uuid)
);

drop trigger if exists race_participants_set_updated_at on public.race_participants;
create trigger race_participants_set_updated_at
before update on public.race_participants
for each row execute procedure trigger_set_timestamp();

create index if not exists idx_race_participants_race  on public.race_participants(race_uuid);
create index if not exists idx_race_participants_owner on public.race_participants(owner_user_id);

alter table public.race_participants enable row level security;

create policy rp_select_own on public.race_participants
  for select using (owner_user_id = auth.uid());
create policy rp_modify_own on public.race_participants
  for insert with check (owner_user_id = auth.uid());
create policy rp_update_own on public.race_participants
  for update using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());
create policy rp_delete_own on public.race_participants
  for delete using (owner_user_id = auth.uid());

commit;
