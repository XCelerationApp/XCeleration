-- Migration: Add ON DELETE CASCADE foreign keys from user-owned tables to auth.users
--
-- Why:
--   owner_user_id / user_id columns in user_profiles, runners, teams, races,
--   and coach_links were plain UUIDs with no FK back to auth.users. Deleting
--   a user via the delete-user Edge Function left orphaned rows in all of these
--   tables. With these constraints in place, a single DELETE on auth.users
--   cascades automatically through the entire ownership tree:
--
--     auth.users
--       → user_profiles
--       → runners     → team_rosters (already cascaded)
--                     → race_participants (already cascaded)
--                     → race_results (already cascaded)
--       → teams       → team_rosters (already cascaded)
--                     → race_team_participation (already cascaded)
--                     → race_participants (already cascaded)
--       → races       → race_participants (already cascaded)
--                     → race_results (already cascaded)
--                     → race_team_participation (already cascaded)
--       → coach_links (both coach and viewer sides)

begin;

alter table public.user_profiles
  add constraint fk_user_profiles_auth_user
  foreign key (user_id)
  references auth.users (id)
  on delete cascade;

alter table public.runners
  add constraint fk_runners_auth_user
  foreign key (owner_user_id)
  references auth.users (id)
  on delete cascade;

alter table public.teams
  add constraint fk_teams_auth_user
  foreign key (owner_user_id)
  references auth.users (id)
  on delete cascade;

alter table public.races
  add constraint fk_races_auth_user
  foreign key (owner_user_id)
  references auth.users (id)
  on delete cascade;

alter table public.coach_links
  add constraint fk_coach_links_coach_auth_user
  foreign key (coach_user_id)
  references auth.users (id)
  on delete cascade;

alter table public.coach_links
  add constraint fk_coach_links_viewer_auth_user
  foreign key (viewer_user_id)
  references auth.users (id)
  on delete cascade;

commit;
