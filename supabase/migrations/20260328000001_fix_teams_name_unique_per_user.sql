-- The global UNIQUE (name) constraint on teams prevents users from creating
-- teams with names already used by other users. Replace it with a per-user
-- constraint so team name uniqueness is scoped to each owner.
ALTER TABLE public.teams DROP CONSTRAINT IF EXISTS teams_name_key;
ALTER TABLE public.teams ADD CONSTRAINT teams_name_owner_key UNIQUE (name, owner_user_id);
