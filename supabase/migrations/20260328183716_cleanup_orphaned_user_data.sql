-- Remove orphaned rows that have no corresponding auth.users entry
delete from public.user_profiles where user_id not in (select id from auth.users);
delete from public.runners where owner_user_id not in (select id from auth.users);
delete from public.teams where owner_user_id not in (select id from auth.users);
delete from public.races where owner_user_id not in (select id from auth.users);
