ALTER TABLE public.runners DROP CONSTRAINT IF EXISTS runners_bib_number_key;
ALTER TABLE public.runners ADD CONSTRAINT runners_bib_number_owner_key UNIQUE (bib_number, owner_user_id);
