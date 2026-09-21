-- 1. Drop trigger-based integrity checks from XCE-619 (replaced below by FKs)

drop trigger if exists race_participants_check_refs on public.race_participants;
drop trigger if exists race_results_check_refs on public.race_results;
drop function if exists public.check_race_participant_refs();
drop function if exists public.check_race_result_refs();

-- 2. Convert text UUID columns to uuid type

alter table public.race_participants
  alter column race_uuid   type uuid using race_uuid::uuid,
  alter column runner_uuid type uuid using runner_uuid::uuid,
  alter column team_uuid   type uuid using team_uuid::uuid,
  alter column uuid        type uuid using uuid::uuid;

alter table public.race_results
  alter column race_uuid   type uuid using race_uuid::uuid,
  alter column runner_uuid type uuid using runner_uuid::uuid;

alter table public.team_rosters
  alter column uuid        type uuid using uuid::uuid,
  alter column team_uuid   type uuid using team_uuid::uuid,
  alter column runner_uuid type uuid using runner_uuid::uuid;

alter table public.race_team_participation
  alter column uuid      type uuid using uuid::uuid,
  alter column race_uuid type uuid using race_uuid::uuid,
  alter column team_uuid type uuid using team_uuid::uuid;

-- 3. Native FKs on race_participants

alter table public.race_participants
  add constraint race_participants_race_uuid_fkey
    foreign key (race_uuid)   references public.races(uuid)   on delete cascade,
  add constraint race_participants_runner_uuid_fkey
    foreign key (runner_uuid) references public.runners(uuid) on delete cascade,
  add constraint race_participants_team_uuid_fkey
    foreign key (team_uuid)   references public.teams(uuid)   on delete set null;

-- 4. Native FKs on race_results

alter table public.race_results
  add constraint race_results_race_uuid_fkey
    foreign key (race_uuid)   references public.races(uuid)   on delete cascade,
  add constraint race_results_runner_uuid_fkey
    foreign key (runner_uuid) references public.runners(uuid) on delete cascade;
