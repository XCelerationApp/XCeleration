-- Migration: Add referential integrity triggers to race_participants and race_results
--
-- race_participants.race_uuid / runner_uuid are stored as text but must reference
-- existing rows in races.uuid / runners.uuid. A native FK is not possible because
-- the column types differ (text vs uuid), so we enforce integrity via BEFORE triggers.
--
-- The same risk exists in race_results (same text columns, same sync pattern), so
-- we add equivalent triggers there as well.

-------------------------------------------------------------------------------
-- race_participants — validate race_uuid and runner_uuid on insert/update
-------------------------------------------------------------------------------

create or replace function public.check_race_participant_refs()
returns trigger language plpgsql as $$
begin
  if not exists (
    select 1 from public.races
    where uuid = new.race_uuid::uuid
      and owner_user_id = new.owner_user_id
  ) then
    raise exception
      'race_participants: race_uuid % does not reference a valid race for owner %',
      new.race_uuid, new.owner_user_id;
  end if;

  if not exists (
    select 1 from public.runners
    where uuid = new.runner_uuid::uuid
      and owner_user_id = new.owner_user_id
  ) then
    raise exception
      'race_participants: runner_uuid % does not reference a valid runner for owner %',
      new.runner_uuid, new.owner_user_id;
  end if;

  return new;
end $$;

drop trigger if exists race_participants_check_refs on public.race_participants;
create trigger race_participants_check_refs
before insert or update on public.race_participants
for each row execute function public.check_race_participant_refs();

-------------------------------------------------------------------------------
-- race_results — validate race_uuid and runner_uuid on insert/update
-- Both columns are nullable in race_results, so skip the check when null.
-------------------------------------------------------------------------------

create or replace function public.check_race_result_refs()
returns trigger language plpgsql as $$
begin
  if new.race_uuid is not null and not exists (
    select 1 from public.races
    where uuid = new.race_uuid::uuid
      and owner_user_id = new.owner_user_id
  ) then
    raise exception
      'race_results: race_uuid % does not reference a valid race for owner %',
      new.race_uuid, new.owner_user_id;
  end if;

  if new.runner_uuid is not null and not exists (
    select 1 from public.runners
    where uuid = new.runner_uuid::uuid
      and owner_user_id = new.owner_user_id
  ) then
    raise exception
      'race_results: runner_uuid % does not reference a valid runner for owner %',
      new.runner_uuid, new.owner_user_id;
  end if;

  return new;
end $$;

drop trigger if exists race_results_check_refs on public.race_results;
create trigger race_results_check_refs
before insert or update on public.race_results
for each row execute function public.check_race_result_refs();
