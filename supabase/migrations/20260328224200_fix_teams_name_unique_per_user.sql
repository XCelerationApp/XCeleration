
-- Drop the global unique constraint on name (prevents users from having teams with the same name)
ALTER TABLE public.teams DROP CONSTRAINT teams_name_key;

-- Add a per-user unique constraint so each user can't have duplicate team names,
-- but different users can share team names
ALTER TABLE public.teams ADD CONSTRAINT teams_name_owner_key UNIQUE (name, owner_user_id);
;
