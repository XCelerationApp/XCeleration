-- Remote Database Schema (Postgres/Supabase)
-- Mirrors the local normalized SQLite schema with sync-friendly fields
-- Run in a Postgres-compatible environment (e.g., Supabase SQL editor)

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
  bib_number    text not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);

drop trigger if exists runners_set_updated_at on public.runners;
create trigger runners_set_updated_at
before update on public.runners
for each row execute procedure trigger_set_timestamp();

alter table public.runners drop constraint if exists runners_bib_number_key;
alter table public.runners add constraint if not exists runners_bib_number_owner_key unique (bib_number, owner_user_id);

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
  name          text not null,
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

alter table public.teams drop constraint if exists teams_name_key;
alter table public.teams add constraint if not exists teams_name_owner_key unique (name, owner_user_id);

create index if not exists idx_teams_name on public.teams(name);
create index if not exists idx_teams_abbreviation on public.teams(abbreviation);

-------------------------------------------------------------------------------
-- TEAM_ROSTERS - Which runners belong to which teams
-------------------------------------------------------------------------------
create table if not exists public.team_rosters (
  team_id       bigint not null references public.teams(team_id) on delete cascade,
  runner_id     bigint not null references public.runners(runner_id) on delete cascade,
  uuid          uuid unique,
  team_uuid     uuid,
  runner_uuid   uuid,
  owner_user_id uuid,
  joined_date   timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  primary key (team_id, runner_id),
  unique (team_uuid, runner_uuid)
);

drop trigger if exists team_rosters_set_updated_at on public.team_rosters;
create trigger team_rosters_set_updated_at
before update on public.team_rosters
for each row execute procedure trigger_set_timestamp();

create index if not exists idx_team_rosters_team on public.team_rosters(team_id);
create index if not exists idx_team_rosters_runner on public.team_rosters(runner_id);
create index if not exists idx_team_rosters_updated_at on public.team_rosters(updated_at);
create index if not exists idx_team_rosters_owner on public.team_rosters(owner_user_id);

alter table public.team_rosters enable row level security;
create policy tr_select_own on public.team_rosters for select using (owner_user_id = auth.uid());
create policy tr_insert_own on public.team_rosters for insert with check (owner_user_id = auth.uid());
create policy tr_update_own on public.team_rosters for update using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());
create policy tr_delete_own on public.team_rosters for delete using (owner_user_id = auth.uid());

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
  uuid                uuid unique,
  race_uuid           uuid,
  team_uuid           uuid,
  owner_user_id       uuid,
  team_color_override bigint,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz,
  primary key (race_id, team_id),
  unique (race_uuid, team_uuid)
);

drop trigger if exists race_team_participation_set_updated_at on public.race_team_participation;
create trigger race_team_participation_set_updated_at
before update on public.race_team_participation
for each row execute procedure trigger_set_timestamp();

create index if not exists idx_race_team_participation_race on public.race_team_participation(race_id);
create index if not exists idx_race_team_participation_updated_at on public.race_team_participation(updated_at);
create index if not exists idx_race_team_participation_owner on public.race_team_participation(owner_user_id);

alter table public.race_team_participation enable row level security;
create policy rtp_select_own on public.race_team_participation for select using (owner_user_id = auth.uid());
create policy rtp_insert_own on public.race_team_participation for insert with check (owner_user_id = auth.uid());
create policy rtp_update_own on public.race_team_participation for update using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());
create policy rtp_delete_own on public.race_team_participation for delete using (owner_user_id = auth.uid());

-------------------------------------------------------------------------------
-- RACE_PARTICIPANTS - Individual runner participation
-- PK is (race_uuid, runner_uuid) — app upserts on this pair.
-- No integer FK columns: cross-device identity is UUID-based.
-- Referential integrity enforced via native FKs on the uuid columns.
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

-- Referential integrity: validate race_uuid and runner_uuid exist on insert/update.
-- Uses text→uuid cast and SECURITY DEFINER to bypass RLS when checking referenced rows.
create or replace function validate_race_participants_refs()
returns trigger language plpgsql security definer as $$
begin
  if not exists (
    select 1 from public.races where uuid = new.race_uuid::uuid
  ) then
    raise exception
      'race_participants: race_uuid % does not reference an existing race', new.race_uuid
      using errcode = 'foreign_key_violation';
  end if;

  if not exists (
    select 1 from public.runners where uuid = new.runner_uuid::uuid
  ) then
    raise exception
      'race_participants: runner_uuid % does not reference an existing runner', new.runner_uuid
      using errcode = 'foreign_key_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists race_participants_check_refs on public.race_participants;
create trigger race_participants_check_refs
  before insert or update on public.race_participants
  for each row execute function validate_race_participants_refs();

-------------------------------------------------------------------------------
-- RACE_RESULTS - Pure results data
-- uuid is the primary key. result_id is a legacy bigserial (kept for history
-- but stripped from app push/pull payloads). runner_id/race_id are nullable
-- legacy columns; identity is carried by runner_uuid/race_uuid.
-- Referential integrity enforced via native FKs on the uuid columns.
-------------------------------------------------------------------------------
create table if not exists public.race_results (
  result_id     bigserial,          -- legacy; not used as PK by app
  uuid          uuid        not null primary key default gen_random_uuid(),
  runner_uuid   uuid                references public.runners(uuid) on delete cascade,
  race_uuid     uuid                references public.races(uuid)   on delete cascade,
  runner_id     bigint,             -- nullable legacy FK (app no longer sends)
  race_id       bigint,             -- nullable legacy FK (app no longer sends)
  team_id       bigint,             -- optional team association
  owner_user_id uuid        not null,
  place         integer,
  finish_time   integer,            -- milliseconds
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  unique (race_uuid, runner_uuid)   -- one result per runner per race
);

drop trigger if exists race_results_set_updated_at on public.race_results;
create trigger race_results_set_updated_at
before update on public.race_results
for each row execute procedure trigger_set_timestamp();

create index if not exists idx_race_results_race_uuid on public.race_results(race_uuid);
create index if not exists idx_race_results_owner     on public.race_results(owner_user_id);

-- Referential integrity: validate race_uuid and runner_uuid exist on insert/update.
-- Null values are permitted (legacy rows may omit them). SECURITY DEFINER bypasses RLS.
create or replace function validate_race_results_refs()
returns trigger language plpgsql security definer as $$
begin
  if new.race_uuid is not null and not exists (
    select 1 from public.races where uuid = new.race_uuid::uuid
  ) then
    raise exception
      'race_results: race_uuid % does not reference an existing race', new.race_uuid
      using errcode = 'foreign_key_violation';
  end if;

  if new.runner_uuid is not null and not exists (
    select 1 from public.runners where uuid = new.runner_uuid::uuid
  ) then
    raise exception
      'race_results: runner_uuid % does not reference an existing runner', new.runner_uuid
      using errcode = 'foreign_key_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists race_results_check_refs on public.race_results;
create trigger race_results_check_refs
  before insert or update on public.race_results
  for each row execute function validate_race_results_refs();

-------------------------------------------------------------------------------
-- Row Level Security (RLS) - per-user ownership policies
-- (team_rosters and race_team_participation RLS defined inline above)
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

commit;


