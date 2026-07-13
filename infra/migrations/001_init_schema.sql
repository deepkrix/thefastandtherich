-- =====================================================================
-- TheFastAndTheRich — Initiales Datenbankschema
-- Migration: 001_init_schema.sql
-- Basis: SRS v2.0, Kapitel 4 (Datenmodell)
-- Zielsystem: PostgreSQL 15+
-- =====================================================================
--
-- Leitprinzipien aus der SRS, die dieses Schema technisch durchsetzt:
--  - Coins werden niemals direkt verändert (Kap. 7.1) -> Ledger-Tabelle
--    "transactions" ist strikt append-only (siehe Trigger unten).
--  - Finanzdaten sind unveränderlich (Core Decision #085).
--  - Kein Status darf übersprungen werden (Kap. 5.1) -> ENUM + Anwendungslogik.
--  - Match-ID folgt dem Format TFR-{Jahr}-{12-stellige Sequenz} (Kap. 4.7).
--
-- =====================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- für gen_random_uuid()

-- ---------------------------------------------------------------------
-- ENUM-Typen
-- ---------------------------------------------------------------------

CREATE TYPE user_status          AS ENUM ('ACTIVE', 'SUSPENDED', 'BANNED', 'DELETED');
CREATE TYPE kyc_status           AS ENUM ('NONE', 'PENDING', 'VERIFIED', 'REJECTED');
CREATE TYPE user_role            AS ENUM ('PLAYER', 'MODERATOR', 'ADMIN');
CREATE TYPE wallet_status        AS ENUM ('ACTIVE', 'FROZEN');
CREATE TYPE transaction_type     AS ENUM ('DEPOSIT', 'ENTRY_FEE', 'PAYOUT', 'REFUND', 'BONUS', 'WITHDRAWAL', 'ADJUSTMENT');
CREATE TYPE game_status          AS ENUM ('ACTIVE', 'DEPRECATED', 'DISABLED');
CREATE TYPE match_status         AS ENUM ('CREATED', 'OPEN', 'PLAYING', 'VALIDATING', 'FINISHED', 'CANCELLED', 'ARCHIVED');
CREATE TYPE participation_status AS ENUM ('RESERVED', 'ACTIVE', 'COMPLETED', 'WITHDRAWN', 'REFUNDED');
CREATE TYPE validation_status    AS ENUM ('PENDING', 'VALID', 'INVALID', 'FLAGGED');
CREATE TYPE ranking_scope        AS ENUM ('ARENA', 'SEASON', 'GLOBAL');

-- ---------------------------------------------------------------------
-- 4.1 users
-- ---------------------------------------------------------------------

CREATE TABLE users (
    user_id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email                    TEXT NOT NULL UNIQUE,
    phone                    TEXT,
    password_hash            TEXT NOT NULL,
    status                   user_status NOT NULL DEFAULT 'ACTIVE',
    kyc_status               kyc_status NOT NULL DEFAULT 'NONE',
    role                     user_role NOT NULL DEFAULT 'PLAYER',
    device_fingerprint_hash  TEXT,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_login_at            TIMESTAMPTZ
);

CREATE INDEX idx_users_status ON users(status);

-- ---------------------------------------------------------------------
-- 4.2 profiles (1:1 mit users)
-- ---------------------------------------------------------------------

CREATE TABLE profiles (
    profile_id     UUID PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    display_name   TEXT NOT NULL UNIQUE,
    avatar_url     TEXT,
    title          TEXT,
    level          INT NOT NULL DEFAULT 1,
    total_matches  INT NOT NULL DEFAULT 0,
    total_wins     INT NOT NULL DEFAULT 0,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 4.5 / 4.6 games & game_versions
-- (game_versions referenziert games; games.current_version_id wird per
--  ALTER TABLE nachträglich gesetzt, um die zirkuläre Abhängigkeit
--  sauber aufzulösen)
-- ---------------------------------------------------------------------

CREATE TABLE games (
    game_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                TEXT NOT NULL,
    category            TEXT NOT NULL,
    current_version_id  UUID,
    status              game_status NOT NULL DEFAULT 'ACTIVE'
);

CREATE TABLE game_versions (
    version_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id         UUID NOT NULL REFERENCES games(game_id) ON DELETE CASCADE,
    version_number  TEXT NOT NULL,
    ruleset         JSONB NOT NULL,
    released_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (game_id, version_number)
);

ALTER TABLE games
    ADD CONSTRAINT fk_games_current_version
    FOREIGN KEY (current_version_id) REFERENCES game_versions(version_id);

-- ---------------------------------------------------------------------
-- 4.3 wallets (1:1 mit users)
-- balance_coins wird NICHT direkt von der Anwendung geschrieben, sondern
-- ausschließlich über fn_apply_transaction() (siehe unten).
-- ---------------------------------------------------------------------

CREATE TABLE wallets (
    wallet_id         UUID PRIMARY KEY REFERENCES users(user_id) ON DELETE RESTRICT,
    balance_coins     BIGINT NOT NULL DEFAULT 0 CHECK (balance_coins >= 0),
    reserved_coins    BIGINT NOT NULL DEFAULT 0 CHECK (reserved_coins >= 0),
    total_deposited   BIGINT NOT NULL DEFAULT 0,
    total_won         BIGINT NOT NULL DEFAULT 0,
    total_lost        BIGINT NOT NULL DEFAULT 0,
    total_withdrawn   BIGINT NOT NULL DEFAULT 0,
    currency_rate     NUMERIC(10,4) NOT NULL DEFAULT 0.01,  -- 1 Coin = 0,01 € (SRS Kap. 7.2)
    status            wallet_status NOT NULL DEFAULT 'ACTIVE',
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 4.4 transactions — append-only Ledger (Double-Entry-Prinzip)
-- ---------------------------------------------------------------------

CREATE TABLE transactions (
    transaction_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id       UUID NOT NULL REFERENCES wallets(wallet_id),
    type            transaction_type NOT NULL,
    amount_coins    BIGINT NOT NULL,          -- vorzeichenbehaftet
    balance_after   BIGINT NOT NULL,          -- Snapshot für Audit
    source          TEXT,
    destination     TEXT,
    reference_id    UUID,                     -- z.B. match_id (als UUID gecastet) oder payment_provider_id
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_transactions_wallet_time ON transactions(wallet_id, created_at DESC);
CREATE INDEX idx_transactions_reference ON transactions(reference_id);

-- Append-only erzwingen: UPDATE und DELETE sind auf Datenbankebene verboten.
-- (SRS Core Decision: "Eine Transaktion wird niemals gelöscht.")
CREATE OR REPLACE FUNCTION fn_forbid_transaction_mutation()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'transactions ist append-only: UPDATE/DELETE nicht erlaubt (transaction_id=%)',
        COALESCE(OLD.transaction_id, NEW.transaction_id);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_transactions_no_update
    BEFORE UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION fn_forbid_transaction_mutation();

CREATE TRIGGER trg_transactions_no_delete
    BEFORE DELETE ON transactions
    FOR EACH ROW EXECUTE FUNCTION fn_forbid_transaction_mutation();

-- Einzige zulässige Schreibroute für Kontostandsänderungen:
-- bucht eine Transaktion UND aktualisiert wallets.balance_coins atomar.
CREATE OR REPLACE FUNCTION fn_apply_transaction(
    p_wallet_id      UUID,
    p_type           transaction_type,
    p_amount_coins   BIGINT,
    p_source         TEXT,
    p_destination    TEXT,
    p_reference_id   UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_new_balance    BIGINT;
    v_transaction_id UUID;
BEGIN
    -- Zeilensperre gegen Race Conditions bei parallelen Buchungen
    PERFORM 1 FROM wallets WHERE wallet_id = p_wallet_id FOR UPDATE;

    UPDATE wallets
       SET balance_coins   = balance_coins + p_amount_coins,
           total_deposited = total_deposited + GREATEST(p_amount_coins, 0) * (p_type = 'DEPOSIT')::INT,
           total_won       = total_won       + GREATEST(p_amount_coins, 0) * (p_type = 'PAYOUT')::INT,
           total_lost      = total_lost      + GREATEST(-p_amount_coins, 0) * (p_type = 'ENTRY_FEE')::INT,
           total_withdrawn = total_withdrawn + GREATEST(-p_amount_coins, 0) * (p_type = 'WITHDRAWAL')::INT,
           updated_at      = now()
     WHERE wallet_id = p_wallet_id
    RETURNING balance_coins INTO v_new_balance;

    IF v_new_balance < 0 THEN
        RAISE EXCEPTION 'Buchung würde negativen Kontostand erzeugen (wallet_id=%, amount=%)',
            p_wallet_id, p_amount_coins;
    END IF;

    INSERT INTO transactions (wallet_id, type, amount_coins, balance_after, source, destination, reference_id)
    VALUES (p_wallet_id, p_type, p_amount_coins, v_new_balance, p_source, p_destination, p_reference_id)
    RETURNING transaction_id INTO v_transaction_id;

    RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- 4.7 matches
-- ---------------------------------------------------------------------

CREATE TABLE matches (
    match_id          TEXT PRIMARY KEY
                        CHECK (match_id ~ '^TFR-[0-9]{4}-[0-9]{12}$'),
    game_id           UUID NOT NULL REFERENCES games(game_id),
    game_version_id   UUID NOT NULL REFERENCES game_versions(version_id),
    arena_id          TEXT NOT NULL,
    stake_coins       INT NOT NULL CHECK (stake_coins IN (1, 2, 5, 10, 100, 500)),
    status            match_status NOT NULL DEFAULT 'CREATED',
    max_participants  INT NOT NULL DEFAULT 500 CHECK (max_participants > 0),
    min_participants  INT NOT NULL DEFAULT 2 CHECK (min_participants >= 2),
    opens_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    closes_at         TIMESTAMPTZ NOT NULL,
    seed              TEXT NOT NULL,
    pot_total_coins   BIGINT NOT NULL DEFAULT 0,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (closes_at > opens_at)
);

-- Lobby-Abfrage: offene Matches einer Kategorie (häufigster Read-Pfad)
CREATE INDEX idx_matches_lobby ON matches(stake_coins, status) WHERE status IN ('OPEN', 'PLAYING');
CREATE INDEX idx_matches_arena ON matches(arena_id);

-- ---------------------------------------------------------------------
-- 4.8 participations
-- ---------------------------------------------------------------------

CREATE TABLE participations (
    participation_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id          TEXT NOT NULL REFERENCES matches(match_id),
    user_id           UUID NOT NULL REFERENCES users(user_id),
    stake_coins       INT NOT NULL,
    joined_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    status            participation_status NOT NULL DEFAULT 'RESERVED'
);

CREATE INDEX idx_participations_match ON participations(match_id);
CREATE INDEX idx_participations_user ON participations(user_id);

-- ---------------------------------------------------------------------
-- 4.9 attempts
-- ---------------------------------------------------------------------

CREATE TABLE attempts (
    attempt_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participation_id    UUID NOT NULL REFERENCES participations(participation_id),
    started_at          TIMESTAMPTZ,
    ended_at            TIMESTAMPTZ,
    duration_ms         INT,
    validation_status   validation_status NOT NULL DEFAULT 'PENDING',
    device_fingerprint  TEXT,
    network_info        JSONB,
    replay_ref          TEXT     -- Verweis auf Objekt-Storage, nicht die Rohdaten selbst
);

CREATE INDEX idx_attempts_participation ON attempts(participation_id);

-- ---------------------------------------------------------------------
-- 4.10 results
-- ---------------------------------------------------------------------

CREATE TABLE results (
    result_id       UUID PRIMARY KEY REFERENCES attempts(attempt_id),
    score           NUMERIC,
    duration_ms     INT,
    rank_in_match   INT,
    validated_at    TIMESTAMPTZ
);

-- ---------------------------------------------------------------------
-- 4.11 rankings
-- ---------------------------------------------------------------------

CREATE TABLE rankings (
    ranking_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scope        ranking_scope NOT NULL,
    user_id      UUID NOT NULL REFERENCES users(user_id),
    rank_value   INT NOT NULL,
    period       TEXT,
    computed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_rankings_scope_period ON rankings(scope, period);

-- ---------------------------------------------------------------------
-- 4.12 achievements, events, audit_logs
-- ---------------------------------------------------------------------

CREATE TABLE achievements (
    achievement_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(user_id),
    type            TEXT NOT NULL,
    unlocked_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE events (
    event_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type       TEXT NOT NULL,
    starts_at  TIMESTAMPTZ,
    ends_at    TIMESTAMPTZ,
    rules      JSONB
);

CREATE TABLE audit_logs (
    log_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id     UUID REFERENCES users(user_id),
    action_type  TEXT NOT NULL,
    target_type  TEXT,
    target_id    TEXT,
    details      JSONB,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_logs_actor_time ON audit_logs(actor_id, created_at DESC);

COMMIT;

-- =====================================================================
-- Hinweise für die Anwendungsschicht (nicht Teil des Schemas selbst):
--
-- 1. Jede Coin-Bewegung MUSS über fn_apply_transaction() laufen.
--    Direkte UPDATEs auf wallets.balance_coins sollten zusätzlich per
--    Datenbank-Rolle (REVOKE UPDATE (balance_coins) ON wallets FROM app_role;
--    GRANT EXECUTE ON FUNCTION fn_apply_transaction TO app_role;) unterbunden
--    werden — das ist hier bewusst nicht Teil der Migration, weil es von
--    eurem Rollen-/Rechtekonzept abhängt.
-- 2. matches.pot_total_coins wird von der Anwendung bei jedem Beitritt
--    inkrementiert (kein Trigger hier, um flexible Rollback-Logik bei
--    fehlgeschlagenen Beitritten zu erlauben).
-- 3. Sharding/Partitionierung von "transactions" und "audit_logs" nach
--    created_at (z.B. via pg_partman) ist ab nennenswertem Volumen zu
--    empfehlen, aber für den MVP (Kap. 14, Phase 0-1) nicht notwendig.
-- =====================================================================
