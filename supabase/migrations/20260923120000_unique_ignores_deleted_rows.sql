-- Deleting is a soft delete: the row stays so every device learns it is gone.
-- A deleted runner therefore still held its bib number and a deleted team its
-- name, which blocked the value being used again — a real case, since bibs are
-- reused between seasons. Uniqueness now ignores deleted rows, matching the
-- partial indexes the local SQLite schema uses.
--
-- Constraints are dropped by the columns they cover rather than by name, so
-- this does not depend on what earlier migrations happened to name them.

do $$
declare
  target record;
  found_name text;
begin
  for target in
    select * from (values
      ('runners',      array['bib_number', 'owner_user_id']),
      ('teams',        array['name', 'owner_user_id']),
      ('race_results', array['race_uuid', 'runner_uuid'])
    ) as t(table_name, columns)
  loop
    select con.conname into found_name
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = target.table_name
      and con.contype = 'u'
      and (
        select array_agg(att.attname::text order by att.attname)
        from unnest(con.conkey) as k(attnum)
        join pg_attribute att
          on att.attrelid = con.conrelid and att.attnum = k.attnum
      ) = (select array_agg(c order by c) from unnest(target.columns) as c);

    if found_name is not null then
      execute format('alter table public.%I drop constraint %I',
                     target.table_name, found_name);
      raise notice 'dropped % on %', found_name, target.table_name;
    end if;
    found_name := null;
  end loop;
end $$;

create unique index if not exists runners_bib_number_owner_live_key
  on public.runners (bib_number, owner_user_id)
  where deleted_at is null;

create unique index if not exists teams_name_owner_live_key
  on public.teams (name, owner_user_id)
  where deleted_at is null;

create unique index if not exists race_results_runner_live_key
  on public.race_results (race_uuid, runner_uuid)
  where deleted_at is null;
