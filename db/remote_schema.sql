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
  name          text not null unique,
  abbreviation  text check (char_length(abbreviation) <= 3),
  color         integer not null default 0, -- ARGB 32-bit int encoded in app
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
  team_color_override integer,
  primary key (race_id, team_id)
);

create index if not exists idx_race_team_participation_race on public.race_team_participation(race_id);

-------------------------------------------------------------------------------
-- RACE_PARTICIPANTS - Individual runner participation
-------------------------------------------------------------------------------
create table if not exists public.race_participants (
  race_id   bigint not null references public.races(race_id) on delete cascade,
  runner_id bigint not null references public.runners(runner_id) on delete cascade,
  team_id   bigint not null references public.teams(team_id) on delete cascade,
  primary key (race_id, runner_id)
);

create index if not exists idx_race_participants_race on public.race_participants(race_id);
create index if not exists idx_race_participants_team on public.race_participants(team_id);

-------------------------------------------------------------------------------
-- RACE_RESULTS - Pure results data
-------------------------------------------------------------------------------
create table if not exists public.race_results (
  result_id   bigserial primary key,
  uuid        uuid not null default gen_random_uuid() unique,
  race_id     bigint not null references public.races(race_id) on delete cascade,
  runner_id   bigint not null references public.runners(runner_id) on delete cascade,
  place       integer,
  finish_time integer, -- milliseconds
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  unique (race_id, runner_id),
  unique (race_id, place)
);

drop trigger if exists race_results_set_updated_at on public.race_results;
create trigger race_results_set_updated_at
before update on public.race_results
for each row execute procedure trigger_set_timestamp();

create index if not exists idx_race_results_race on public.race_results(race_id);
create index if not exists idx_race_results_place on public.race_results(race_id, place);

-------------------------------------------------------------------------------
-- (Optional) Row Level Security (RLS) scaffolding for multi-user scenarios
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


