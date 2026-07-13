-- =====================================================================
-- TheFastAndTheRich — Match-Seeding für MVP-Tests
-- Migration: 004_seed_matches.sql
-- =====================================================================

BEGIN;

-- Funktion: Erstellt automatisch ein offenes Match pro Stake-Kategorie
-- wenn weniger als 3 offene Matches existieren
CREATE OR REPLACE FUNCTION fn_ensure_open_matches()
RETURNS void AS $$
DECLARE
    v_stake INT;
    v_game_id UUID;
    v_version_id UUID;
    v_match_id TEXT;
    v_arena_id TEXT;
    v_count INT;
    v_seed TEXT;
BEGIN
    SELECT game_id INTO v_game_id FROM games WHERE name = 'Reaction Tap' LIMIT 1;
    IF v_game_id IS NULL THEN
        RETURN;
    END IF;

    SELECT version_id INTO v_version_id FROM game_versions WHERE game_id = v_game_id LIMIT 1;
    IF v_version_id IS NULL THEN
        RETURN;
    END IF;

    FOREACH v_stake IN ARRAY ARRAY[1, 2, 5, 10, 100, 500]
    LOOP
        SELECT COUNT(*) INTO v_count 
        FROM matches 
        WHERE stake_coins = v_stake AND status = 'OPEN';

        IF v_count < 2 THEN
            v_match_id := 'TFR-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(FLOOR(RANDOM() * 900000000000 + 100000000000)::TEXT, 12, '0');
            v_arena_id := 'arena-' || v_stake || '-' || TO_CHAR(NOW(), 'YYYYMMDDHH24');
            v_seed := SUBSTRING(MD5(RANDOM()::TEXT), 1, 8);

            INSERT INTO matches (match_id, game_id, game_version_id, arena_id, stake_coins, status, max_participants, min_participants, opens_at, closes_at, seed, pot_total_coins)
            VALUES (v_match_id, v_game_id, v_version_id, v_arena_id, v_stake, 'OPEN', 500, 2, NOW(), NOW() + INTERVAL '5 minutes', v_seed, 0);
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Einmalig ausführen
SELECT fn_ensure_open_matches();

COMMIT;
