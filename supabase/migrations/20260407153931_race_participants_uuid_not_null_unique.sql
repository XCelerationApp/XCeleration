-- Backfill any existing nulls
UPDATE race_participants SET uuid = gen_random_uuid() WHERE uuid IS NULL;

-- Add default, NOT NULL, and UNIQUE
ALTER TABLE race_participants ALTER COLUMN uuid SET DEFAULT gen_random_uuid();
ALTER TABLE race_participants ALTER COLUMN uuid SET NOT NULL;
ALTER TABLE race_participants ADD CONSTRAINT race_participants_uuid_key UNIQUE (uuid);
