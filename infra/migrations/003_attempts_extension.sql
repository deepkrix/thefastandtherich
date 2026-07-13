-- =====================================================================
-- TheFastAndTheRich — Attempts-Erweiterung für Spiel-Input
-- Migration: 003_attempts_extension.sql
-- =====================================================================

BEGIN;

ALTER TABLE attempts ADD COLUMN IF NOT EXISTS input_payload TEXT;
ALTER TABLE attempts ADD COLUMN IF NOT EXISTS client_duration_ms INT;

COMMIT;
