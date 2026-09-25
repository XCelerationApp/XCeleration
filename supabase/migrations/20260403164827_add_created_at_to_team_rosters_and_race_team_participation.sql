ALTER TABLE public.team_rosters
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.race_team_participation
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();
