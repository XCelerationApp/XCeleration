-- Migration: Convert text UUID columns to uuid type and replace trigger-based
-- integrity checks with native FK constraints.
--
-- Previously (XCE-619) we used BEFORE triggers to validate race_uuid/runner_uuid
-- on race_participants and race_results. Now that all columns are valid UUIDs
-- (0 invalid values confirmed by audit), we can use native FKs which are more
-- efficient, handled by Postgres storage rather than plpgsql, and also provide
-- ON DELETE behaviour to prevent orphans at the root.
--
-- Tables affected:
--   race_participants       — race_uuid, runner_uuid (PK cols), team_uuid, uuid
--   race_results            — race_uuid, runner_uuid
--   team_rosters            — uuid, team_uuid, runner_uuid  (type-only; already FK'd via _id cols)
--   race_team_participation — uuid, race_uuid, team_uuid    (type-only; already FK'd via _id cols)

-------------------------------------------------------------------------------
-- 1. Drop trigger-based integrity checks from XCE-619 (replaced below by FKs)
-------------------------------------------------------------------------------

drop trigger if exists race_participants_check_refs on public.race_participants;
drop trigger if exists race_results_check_refs on public.race_results;
drop function if exists public.check_race_participant_refs();
drop function if exists public.check_race_result_refs();

-------------------------------------------------------------------------------
-- 2. Convert text UUID columns to uuid type
-------------------------------------------------------------------------------

-- race_participants (race_uuid and runner_uuid form the PK)
alter table public.race_participants
  alter column race_uuid   type uuid using race_uuid::uuid,
  alter column runner_uuid type uuid using runner_uuid::uuid,
  alter column team_uuid   type uuid using team_uuid::uuid,
  alter column uuid        type uuid using uuid::uuid;

-- race_results
alter table public.race_results
  alter column race_uuid   type uuid using race_uuid::uuid,
  alter column runner_uuid type uuid using runner_uuid::uuid;

-- team_rosters (integrity already enforced by team_id/runner_id integer FKs)
alter table public.team_rosters
  alter column uuid        type uuid using uuid::uuid,
  alter column team_uuid   type uuid using team_uuid::uuid,
  alter column runner_uuid type uuid using runner_uuid::uuid;

-- race_team_participation (integrity already enforced by race_id/team_id integer FKs)
alter table public.race_team_participation
  alter column uuid      type uuid using uuid::uuid,
  alter column race_uuid type uuid using race_uuid::uuid,
  alter column team_uuid type uuid using team_uuid::uuid;

-------------------------------------------------------------------------------
-- 3. Add native FK constraints on race_participants
--
-- race_uuid / runner_uuid: ON DELETE CASCADE — if the race or runner is hard-
--   deleted, remove the participation rows (prevents orphans at the root).
-- team_uuid: ON DELETE SET NULL — team membership is optional; if a team is
--   hard-deleted, null out the reference rather than removing the participation.
-------------------------------------------------------------------------------

alter table public.race_participants
  add constraint race_participants_race_uuid_fkey
    foreign key (race_uuid)   references public.races(uuid)   on delete cascade,
  add constraint race_participants_runner_uuid_fkey
    foreign key (runner_uuid) references public.runners(uuid) on delete cascade,
  add constraint race_participants_team_uuid_fkey
    foreign key (team_uuid)   references public.teams(uuid)   on delete set null;

-------------------------------------------------------------------------------
-- 4. Add native FK constraints on race_results
--
-- Both columns are nullable; ON DELETE CASCADE mirrors race_participants logic.
-------------------------------------------------------------------------------

alter table public.race_results
  add constraint race_results_race_uuid_fkey
    foreign key (race_uuid)   references public.races(uuid)   on delete cascade,
  add constraint race_results_runner_uuid_fkey
    foreign key (runner_uuid) references public.runners(uuid) on delete cascade;
