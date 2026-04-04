-- The global UNIQUE (bib_number) constraint on runners prevents users from
-- creating runners with bib numbers already used by any other user. With RLS,
-- data is already scoped per-owner, but the UNIQUE constraint is enforced at
-- the table level across all rows. Replace it with a per-user constraint so
-- bib number uniqueness is scoped to each owner.
ALTER TABLE public.runners DROP CONSTRAINT IF EXISTS runners_bib_number_key;
ALTER TABLE public.runners ADD CONSTRAINT runners_bib_number_owner_key UNIQUE (bib_number, owner_user_id);
