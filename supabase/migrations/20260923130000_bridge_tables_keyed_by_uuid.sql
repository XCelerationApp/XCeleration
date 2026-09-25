-- team_rosters and race_team_participation still carry their parents as
-- integer ids, with the primary key and foreign keys on those columns. Those
-- ids belong to whichever device wrote the row, so no client can supply them:
-- a phone knows its own runner_id, not the server's. The tables cannot be
-- written at all as they stand, which is why both are still empty.
--
-- Identity moves to the uuid pair, exactly as race_participants already does.
-- Both tables have no rows, so nothing is migrated or at risk.

-------------------------------------------------------------------------------
-- TEAM_ROSTERS
-------------------------------------------------------------------------------
alter table public.team_rosters drop constraint if exists team_rosters_pkey;
alter table public.team_rosters drop constraint if exists team_rosters_team_id_fkey;
alter table public.team_rosters drop constraint if exists team_rosters_runner_id_fkey;
alter table public.team_rosters drop column if exists team_id;
alter table public.team_rosters drop column if exists runner_id;

alter table public.team_rosters
  alter column team_uuid type uuid using team_uuid::uuid,
  alter column runner_uuid type uuid using runner_uuid::uuid,
  alter column uuid type uuid using uuid::uuid;
alter table public.team_rosters
  alter column team_uuid set not null,
  alter column runner_uuid set not null,
  alter column owner_user_id set not null,
  alter column uuid set default gen_random_uuid(),
  alter column uuid set not null;

alter table public.team_rosters
  drop constraint if exists team_rosters_team_uuid_runner_uuid_key;
alter table public.team_rosters
  add constraint team_rosters_pkey primary key (team_uuid, runner_uuid);
alter table public.team_rosters
  add constraint team_rosters_team_uuid_fkey
  foreign key (team_uuid) references public.teams(uuid) on delete cascade;
alter table public.team_rosters
  add constraint team_rosters_runner_uuid_fkey
  foreign key (runner_uuid) references public.runners(uuid) on delete cascade;

-------------------------------------------------------------------------------
-- RACE_TEAM_PARTICIPATION
-------------------------------------------------------------------------------
alter table public.race_team_participation
  drop constraint if exists race_team_participation_pkey;
alter table public.race_team_participation
  drop constraint if exists race_team_participation_race_id_fkey;
alter table public.race_team_participation
  drop constraint if exists race_team_participation_team_id_fkey;
alter table public.race_team_participation drop column if exists race_id;
alter table public.race_team_participation drop column if exists team_id;

alter table public.race_team_participation
  alter column race_uuid type uuid using race_uuid::uuid,
  alter column team_uuid type uuid using team_uuid::uuid,
  alter column uuid type uuid using uuid::uuid;
alter table public.race_team_participation
  alter column race_uuid set not null,
  alter column team_uuid set not null,
  alter column owner_user_id set not null,
  alter column uuid set default gen_random_uuid(),
  alter column uuid set not null;

alter table public.race_team_participation
  drop constraint if exists race_team_participation_race_uuid_team_uuid_key;
alter table public.race_team_participation
  add constraint race_team_participation_pkey primary key (race_uuid, team_uuid);
alter table public.race_team_participation
  add constraint race_team_participation_race_uuid_fkey
  foreign key (race_uuid) references public.races(uuid) on delete cascade;
alter table public.race_team_participation
  add constraint race_team_participation_team_uuid_fkey
  foreign key (team_uuid) references public.teams(uuid) on delete cascade;
