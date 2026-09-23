-- Remote Database Schema (Postgres/Supabase)
-- Mirrors the local normalized SQLite schema with sync-friendly fields
-- Run in a Postgres-compatible environment (e.g., Supabase SQL editor)
--
-- This file describes the shape of the live database. The migrations under
-- supabase/migrations are what actually built it; keep this in step with them.

begin;

-- Extensions for UUID generation (Supabase has pgcrypto enabled by default)
create extension if not exists "pgcrypto";

-- Helper trigger to auto-update updated_at on writes
create or replace function trigger_set_timestamp()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-------------------------------------------------------------------------------
-- RUNNERS - Global runners with permanent bib numbers
-------------------------------------------------------------------------------
create table if not exists public.runners (
  runner_id     bigserial primary key,
  uuid          uuid not null default gen_random_uuid() unique,
  owner_user_id uuid not null,
  name          text not null check (char_length(name) > 0),
  grade         integer check (grade between 9 and 12),
  bib_number    text not null unique,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);

drop trigger if exists runners_set_updated_at on public.runners;
create trigger runners_set_updated_at
before update on public.runners
for each row execute procedure trigger_set_timestamp();

create index if not exists idx_runners_name_grade on public.runners(name, grade);
create index if not exists idx_runners_name on public.runners(name);
create index if not exists idx_runners_bib on public.runners(bib_number);

-------------------------------------------------------------------------------
-- TEAMS - Global teams with abbreviations and colors
-------------------------------------------------------------------------------
create table if not exists public.teams (
  team_id       bigserial primary key,
  uuid          uuid not null default gen_random_uuid() unique,
  owner_user_id uuid not null,
  name          text not null unique,
  abbreviation  text check (char_length(abbreviation) <= 3),
  color         bigint not null default 0,  -- ARGB 32-bit unsigned int encoded in app; bigint avoids signed overflow
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);

drop trigger if exists teams_set_updated_at on public.teams;
create trigger teams_set_updated_at
before update on public.teams
for each row execute procedure trigger_set_timestamp();

create index if not exists idx_teams_name on public.teams(name);
create index if not exists idx_teams_abbreviation on public.teams(abbreviation);

-------------------------------------------------------------------------------
-- TEAM_ROSTERS - Which runners belong to which teams
-------------------------------------------------------------------------------
create table if not exists public.team_rosters (
  team_id       bigint not null references public.teams(team_id) on delete cascade,
  runner_id     bigint not null references public.runners(runner_id) on delete cascade,
  joined_date   timestamptz not null default now(),
  uuid          uuid unique,
  team_uuid     uuid,
  runner_uuid   uuid,
  owner_user_id uuid,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  primary key (team_id, runner_id)
);

create index if not exists idx_team_rosters_team on public.team_rosters(team_id);
create index if not exists idx_team_rosters_runner on public.team_rosters(runner_id);

-------------------------------------------------------------------------------
-- RACES - Core race information
-------------------------------------------------------------------------------
create table if not exists public.races (
  race_id       bigserial primary key,
  uuid          uuid not null default gen_random_uuid() unique,
  owner_user_id uuid not null,
  name          text not null,
  race_date     timestamptz,
  location      text not null default '',
  distance      double precision not null default 0,
  distance_unit text not null default 'mi',
  flow_state    text not null default 'setup',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);

drop trigger if exists races_set_updated_at on public.races;
create trigger races_set_updated_at
before update on public.races
for each row execute procedure trigger_set_timestamp();

create index if not exists idx_races_date on public.races(race_date);

-------------------------------------------------------------------------------
-- RACE_TEAM_PARTICIPATION - Teams participating in races
-------------------------------------------------------------------------------
create table if not exists public.race_team_participation (
  race_id             bigint not null references public.races(race_id) on delete cascade,
  team_id             bigint not null references public.teams(team_id) on delete cascade,
  team_color_override bigint,  -- ARGB 32-bit unsigned; same encoding as teams.color
  uuid                uuid unique,
  race_uuid           uuid,
  team_uuid           uuid,
  owner_user_id       uuid,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz,
  primary key (race_id, team_id)
);

create index if not exists idx_race_team_participation_race on public.race_team_participation(race_id);

-------------------------------------------------------------------------------
-- RACE_PARTICIPANTS - Individual runner participation
-- PK is (race_uuid, runner_uuid) — app upserts on this pair, and it is what
-- the app matches a pulled row to its local one by. The uuid column below is a
-- server-side surrogate key with no local counterpart; the app never sends it.
-- No integer FK columns: cross-device identity is UUID-based.
-------------------------------------------------------------------------------
create table if not exists public.race_participants (
  race_uuid     uuid        not null references public.races(uuid)   on delete cascade,
  runner_uuid   uuid        not null references public.runners(uuid) on delete cascade,
  team_uuid     uuid                 references public.teams(uuid)   on delete set null,
  owner_user_id uuid        not null,
  uuid          uuid        not null default gen_random_uuid() unique,
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

-------------------------------------------------------------------------------
-- RACE_RESULTS - Pure results data
-- uuid is the primary key. result_id is a legacy bigserial (kept for history
-- but stripped from app push/pull payloads). runner_id/race_id are nullable
-- legacy columns; identity is carried by runner_uuid/race_uuid.
-------------------------------------------------------------------------------
create table if not exists public.race_results (
  result_id   bigserial,            -- legacy; not used as PK by app
  uuid        uuid        not null primary key default gen_random_uuid(),
  runner_uuid uuid references public.runners(uuid) on delete cascade,
  race_uuid   uuid references public.races(uuid)   on delete cascade,
  runner_id   bigint,               -- nullable legacy FK (app no longer sends)
  race_id     bigint,               -- nullable legacy FK (app no longer sends)
  team_id     bigint,               -- optional team association
  owner_user_id uuid       not null,
  place       integer,
  finish_time integer,              -- milliseconds
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  -- One LIVE result per runner per race; see the partial unique index below.
);

drop trigger if exists race_results_set_updated_at on public.race_results;
create trigger race_results_set_updated_at
before update on public.race_results
for each row execute procedure trigger_set_timestamp();

-- Uniqueness ignores soft-deleted rows, so a deleted runner's bib number,
-- a deleted team's name and a removed result do not block the value being
-- used again. The local SQLite schema carries the same partial indexes.
create unique index if not exists race_results_runner_live_key
  on public.race_results (race_uuid, runner_uuid) where deleted_at is null;
create unique index if not exists runners_bib_number_owner_live_key
  on public.runners (bib_number, owner_user_id) where deleted_at is null;
create unique index if not exists teams_name_owner_live_key
  on public.teams (name, owner_user_id) where deleted_at is null;

create index if not exists idx_race_results_race_uuid on public.race_results(race_uuid);
create index if not exists idx_race_results_owner     on public.race_results(owner_user_id);

-------------------------------------------------------------------------------
-- Row Level Security (RLS) - per-user ownership policies
alter table public.runners enable row level security;
alter table public.teams enable row level security;
alter table public.races enable row level security;
alter table public.race_participants enable row level security;
alter table public.race_results enable row level security;

-- Allow anonymous users to access their own data; auth.uid() works for both authenticated and anonymous users
create policy runners_select_own on public.runners for select using (owner_user_id = auth.uid());
create policy runners_modify_own on public.runners for insert with check (owner_user_id = auth.uid());
create policy runners_update_own on public.runners for update using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());
create policy runners_delete_own on public.runners for delete using (owner_user_id = auth.uid());

create policy teams_select_own on public.teams for select using (owner_user_id = auth.uid());
create policy teams_modify_own on public.teams for insert with check (owner_user_id = auth.uid());
create policy teams_update_own on public.teams for update using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());
create policy teams_delete_own on public.teams for delete using (owner_user_id = auth.uid());

create policy races_select_own on public.races for select using (owner_user_id = auth.uid());
create policy races_modify_own on public.races for insert with check (owner_user_id = auth.uid());
create policy races_update_own on public.races for update using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());
create policy races_delete_own on public.races for delete using (owner_user_id = auth.uid());

-- race_participants: owner_user_id is stored directly on the row
create policy rp_select_own on public.race_participants for select using (owner_user_id = auth.uid());
create policy rp_modify_own on public.race_participants for insert with check (owner_user_id = auth.uid());
create policy rp_update_own on public.race_participants for update using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());
create policy rp_delete_own on public.race_participants for delete using (owner_user_id = auth.uid());

-- race_results: owner_user_id is stored directly on the row
create policy rr_select_own on public.race_results for select using (owner_user_id = auth.uid());
create policy rr_modify_own on public.race_results for insert with check (owner_user_id = auth.uid());
create policy rr_update_own on public.race_results for update using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());
create policy rr_delete_own on public.race_results for delete using (owner_user_id = auth.uid());

-------------------------------------------------------------------------------
-- USER_PROFILES - Public profile info linked to auth.users
-------------------------------------------------------------------------------
create table if not exists public.user_profiles (
  user_id      uuid primary key,
  email        text not null,
  display_name text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

drop trigger if exists user_profiles_set_updated_at on public.user_profiles;
create trigger user_profiles_set_updated_at
before update on public.user_profiles
for each row execute procedure trigger_set_timestamp();

alter table public.user_profiles enable row level security;
create policy profiles_select_all on public.user_profiles for select using (true);
create policy profiles_upsert_own on public.user_profiles for insert with check (user_id = auth.uid());
create policy profiles_update_own on public.user_profiles for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-------------------------------------------------------------------------------
-- COACH_LINKS - Links a coach (owner) to a viewer
-------------------------------------------------------------------------------
create table if not exists public.coach_links (
  coach_user_id  uuid not null,
  viewer_user_id uuid not null,
  created_at     timestamptz not null default now(),
  primary key (coach_user_id, viewer_user_id)
);

alter table public.coach_links enable row level security;
create policy coach_links_view on public.coach_links for select using (viewer_user_id = auth.uid() or coach_user_id = auth.uid());
create policy coach_links_insert_self on public.coach_links for insert with check (viewer_user_id = auth.uid());
create policy coach_links_delete_self on public.coach_links for delete using (viewer_user_id = auth.uid() or coach_user_id = auth.uid());

-------------------------------------------------------------------------------
-- alter table public.runners enable row level security;
-- alter table public.teams enable row level security;
-- alter table public.team_rosters enable row level security;
-- alter table public.races enable row level security;
-- alter table public.race_team_participation enable row level security;
-- alter table public.race_participants enable row level security;
-- alter table public.race_results enable row level security;
--
-- Example policy (adjust to your auth model):
-- create policy "allow all" on public.runners for all using (true);

commit;


