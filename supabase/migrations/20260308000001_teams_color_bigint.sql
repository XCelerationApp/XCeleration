-- Migration: Widen teams.color from integer to bigint
--
-- Why:
--   Flutter stores Color values as unsigned 32-bit ARGB integers (0x00000000
--   to 0xFFFFFFFF). PostgreSQL `integer` is signed 32-bit (max 2,147,483,647),
--   so any color with full-opacity (alpha = 0xFF) overflows on insert/upsert.
--   Widening to bigint (64-bit signed) accommodates the full Flutter color range.

begin;

alter table public.teams
  alter column color type bigint;

commit;
