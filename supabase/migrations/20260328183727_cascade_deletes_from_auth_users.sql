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
