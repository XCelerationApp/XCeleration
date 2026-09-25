-- Migration: Add referential integrity triggers to race_participants and race_results
-- XCE-619
--
-- Why:
--   race_participants rows with dangling race_uuid or runner_uuid references
--   (pointing to races/runners deleted from the DB) cause the sync service to
--   skip them indefinitely. 13 orphaned rows were manually removed 2026-04-04.
--   This migration prevents such rows from being inserted in the first place.
--
--   race_uuid/runner_uuid are stored as text (not typed uuid FKs) so a native
--   FK constraint cannot reference the uuid columns on races/runners. Triggers
--   are used instead and run SECURITY DEFINER to bypass RLS when checking for
--   referenced rows.
--
-- Apply in: Supabase SQL editor (run as one transaction).

begin;

-- ================================================================
-- 1. RACE_PARTICIPANTS — validate race_uuid and runner_uuid on write
-- ================================================================

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

-- ================================================================
-- 2. RACE_RESULTS — same protection applied proactively
--    Audit (2026-04-04) found 0 orphans, but the same structural risk
--    exists: race_uuid/runner_uuid are nullable text with no FK enforcement.
--    Null values are allowed (legacy rows may omit them).
-- ================================================================

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

commit;
