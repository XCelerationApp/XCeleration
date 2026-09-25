-- 1. user_profiles: stop exposing every user's email. Signed-in users can read
--    their own profile and the profiles of coaches/viewers they are linked to.
drop policy if exists profiles_select_all on public.user_profiles;
create policy profiles_select_self_or_linked on public.user_profiles
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1 from public.coach_links cl
      where (cl.viewer_user_id = (select auth.uid()) and cl.coach_user_id = user_profiles.user_id)
         or (cl.coach_user_id = (select auth.uid()) and cl.viewer_user_id = user_profiles.user_id)
    )
  );

-- 2. Linking a coach by email needs to find their user id before any link
--    exists. Expose only that lookup (returns just the id), signed-in only.
create or replace function public.find_user_id_by_email(p_email text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select user_id from public.user_profiles
  where lower(email) = lower(trim(p_email))
  limit 1
$$;
revoke all on function public.find_user_id_by_email(text) from public, anon;
grant execute on function public.find_user_id_by_email(text) to authenticated;

-- 3. The SECURITY DEFINER existence checks re-added in
--    20260409061321 duplicate the native FKs added in 20260404144527
--    (race_participants/race_results -> races/runners by uuid). Drop them.
drop trigger if exists race_participants_check_refs on public.race_participants;
drop trigger if exists race_results_check_refs on public.race_results;
drop function if exists public.validate_race_participants_refs();
drop function if exists public.validate_race_results_refs();

-- 4. Pin search_path (body only uses now()).
alter function public.trigger_set_timestamp() set search_path = '';

-- 5. Signed-out (anon) clients never need the app's tables; RLS already
--    returns nothing to them, this removes the tables from their API/GraphQL.
revoke select, insert, update, delete
  on public.runners, public.teams, public.team_rosters, public.races,
     public.race_team_participation, public.race_participants,
     public.race_results, public.user_profiles, public.coach_links
  from anon;
