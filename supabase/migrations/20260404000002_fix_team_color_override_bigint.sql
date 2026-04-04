-- Migration: Fix team_color_override column type from integer to bigint
--
-- teams.color is bigint to avoid signed overflow for ARGB 32-bit unsigned
-- values. team_color_override serves the same purpose and should match.

alter table public.race_team_participation
  alter column team_color_override type bigint;
