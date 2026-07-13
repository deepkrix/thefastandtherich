package match

import (
	"context"
	"fmt"
	"math/rand"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/thefastandtherich/backend/internal/models"
)

type Service struct {
	db *pgxpool.Pool
}

func NewService(db *pgxpool.Pool) *Service {
	return &Service{db: db}
}

func generateMatchID() string {
	now := time.Now()
	seq := rand.Intn(900000000) + 100000000
	return fmt.Sprintf("TFR-%d-%012d", now.Year(), seq)
}

func generateArenaID(stakeCoins int) string {
	hourBucket := time.Now().Format("2006010215")
	return fmt.Sprintf("arena-%d-%s", stakeCoins, hourBucket)
}

func (s *Service) EnsureOpenMatches(ctx context.Context) error {
	_, err := s.db.Exec(ctx, `SELECT fn_ensure_open_matches()`)
	return err
}

func (s *Service) CreateMatch(ctx context.Context, gameID, gameVersionID string, stakeCoins int) (*models.Match, error) {
	matchID := generateMatchID()
	arenaID := generateArenaID(stakeCoins)
	seed := uuid.New().String()[:8]

	now := time.Now()
	closesAt := now.Add(5 * time.Minute)

	_, err := s.db.Exec(ctx, `
		INSERT INTO matches (match_id, game_id, game_version_id, arena_id, stake_coins, status, max_participants, min_participants, opens_at, closes_at, seed, pot_total_coins)
		VALUES ($1, $2, $3, $4, $5, 'OPEN', 500, 2, $6, $7, $8, 0)
	`, matchID, gameID, gameVersionID, arenaID, stakeCoins, now, closesAt, seed)
	if err != nil {
		return nil, err
	}

	return s.GetMatch(ctx, matchID)
}

func (s *Service) GetMatch(ctx context.Context, matchID string) (*models.Match, error) {
	var m models.Match
	err := s.db.QueryRow(ctx, `
		SELECT match_id, game_id, arena_id, stake_coins, status, max_participants, min_participants, pot_total_coins, opens_at, closes_at
		FROM matches WHERE match_id = $1
	`, matchID).Scan(&m.MatchID, &m.GameID, &m.ArenaID, &m.StakeCoins, &m.Status, &m.MaxParticipants, &m.MinParticipants, &m.PotTotalCoins, &m.OpensAt, &m.ClosesAt)
	if err != nil {
		return nil, err
	}
	return &m, nil
}

func (s *Service) GetOpenMatches(ctx context.Context, category int) ([]models.Match, error) {
	// Stelle sicher, dass genug offene Matches existieren
	_ = s.EnsureOpenMatches(ctx)

	rows, err := s.db.Query(ctx, `
		SELECT match_id, game_id, arena_id, stake_coins, status, max_participants, min_participants, pot_total_coins, opens_at, closes_at
		FROM matches
		WHERE stake_coins = $1 AND status IN ('OPEN', 'PLAYING')
		ORDER BY opens_at DESC
		LIMIT 10
	`, category)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var matches []models.Match
	for rows.Next() {
		var m models.Match
		err := rows.Scan(&m.MatchID, &m.GameID, &m.ArenaID, &m.StakeCoins, &m.Status, &m.MaxParticipants, &m.MinParticipants, &m.PotTotalCoins, &m.OpensAt, &m.ClosesAt)
		if err != nil {
			continue
		}
		matches = append(matches, m)
	}
	return matches, nil
}

func (s *Service) GetMatchParticipantCount(ctx context.Context, matchID string) (int, error) {
	var count int
	err := s.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM participations WHERE match_id = $1
	`, matchID).Scan(&count)
	return count, err
}

func (s *Service) JoinMatch(ctx context.Context, userID, matchID string, deviceInfo models.ClientDeviceInfo) (*models.JoinMatchResponse, error) {
	var matchStatus string
	var stakeCoins int
	var gameID, gameVersionID, seed string
	err := s.db.QueryRow(ctx, `
		SELECT status, stake_coins, game_id, game_version_id, seed
		FROM matches WHERE match_id = $1
	`, matchID).Scan(&matchStatus, &stakeCoins, &gameID, &gameVersionID, &seed)
	if err != nil {
		return nil, fmt.Errorf("match not found")
	}
	if matchStatus != "OPEN" {
		return nil, fmt.Errorf("match not open")
	}

	var userStatus string
	err = s.db.QueryRow(ctx, `SELECT status FROM users WHERE user_id = $1`, userID).Scan(&userStatus)
	if err != nil {
		return nil, fmt.Errorf("user not found")
	}
	if userStatus != "ACTIVE" {
		return nil, fmt.Errorf("user not active")
	}

	var balance, reserved int64
	err = s.db.QueryRow(ctx, `SELECT balance_coins, reserved_coins FROM wallets WHERE wallet_id = $1`, userID).Scan(&balance, &reserved)
	if err != nil {
		return nil, fmt.Errorf("wallet not found")
	}
	if balance < int64(stakeCoins) {
		return nil, fmt.Errorf("insufficient balance")
	}

	var exists bool
	err = s.db.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM participations WHERE match_id = $1 AND user_id = $2)
	`, matchID, userID).Scan(&exists)
	if err != nil {
		return nil, err
	}
	if exists {
		return nil, fmt.Errorf("already joined")
	}

	attemptID := uuid.New().String()
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var txID string
	err = tx.QueryRow(ctx, `
		SELECT fn_apply_transaction($1, $2, $3, $4, $5, $6)
	`, userID, "ENTRY_FEE", -stakeCoins, "wallet", "match_reservation", matchID).Scan(&txID)
	if err != nil {
		return nil, fmt.Errorf("reservation failed: %w", err)
	}

	_, err = tx.Exec(ctx, `
		UPDATE wallets SET reserved_coins = reserved_coins + $1 WHERE wallet_id = $2
	`, stakeCoins, userID)
	if err != nil {
		return nil, err
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO participations (match_id, user_id, stake_coins, status)
		VALUES ($1, $2, $3, 'RESERVED')
	`, matchID, userID, stakeCoins)
	if err != nil {
		return nil, err
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO attempts (attempt_id, participation_id, started_at, validation_status, device_fingerprint)
		VALUES ($1, (SELECT participation_id FROM participations WHERE match_id = $2 AND user_id = $3), NOW(), 'PENDING', $4)
	`, attemptID, matchID, userID, deviceInfo.Platform)
	if err != nil {
		return nil, err
	}

	_, err = tx.Exec(ctx, `
		UPDATE matches SET pot_total_coins = pot_total_coins + $1 WHERE match_id = $2
	`, stakeCoins, matchID)
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}

	return &models.JoinMatchResponse{
		MatchID:         matchID,
		AttemptID:       attemptID,
		GameConfig:      models.GameConfig{GameID: gameID, Version: "1.0.0", Seed: seed},
		ServerTimestamp: time.Now(),
		SecurityToken:   uuid.New().String(),
	}, nil
}

func (s *Service) SubmitAttempt(ctx context.Context, attemptID string, payload string, durationMs int) error {
	_, err := s.db.Exec(ctx, `
		UPDATE attempts
		SET input_payload = $1, client_duration_ms = $2, ended_at = NOW(), duration_ms = $2
		WHERE attempt_id = $3
	`, payload, durationMs, attemptID)
	return err
}

func (s *Service) FinishMatch(ctx context.Context, matchID string) (*models.MatchResults, error) {
	_, err := s.db.Exec(ctx, `UPDATE matches SET status = 'VALIDATING' WHERE match_id = $1`, matchID)
	if err != nil {
		return nil, err
	}

	rows, err := s.db.Query(ctx, `
		SELECT a.attempt_id, p.user_id, a.duration_ms
		FROM attempts a
		JOIN participations p ON p.participation_id = a.participation_id
		WHERE p.match_id = $1 AND a.validation_status = 'PENDING'
		ORDER BY a.duration_ms ASC NULLS LAST
	`, matchID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	type rankingEntry struct {
		AttemptID  string
		UserID     string
		DurationMs int
		Rank       int
	}
	var rankings []rankingEntry
	rank := 1
	for rows.Next() {
		var r rankingEntry
		err := rows.Scan(&r.AttemptID, &r.UserID, &r.DurationMs)
		if err != nil {
			continue
		}
		r.Rank = rank
		rankings = append(rankings, r)
		rank++
	}

	if len(rankings) == 0 {
		_, err = s.db.Exec(ctx, `UPDATE matches SET status = 'CANCELLED' WHERE match_id = $1`, matchID)
		if err != nil {
			return nil, err
		}
		return &models.MatchResults{MatchID: matchID, Status: "CANCELLED"}, nil
	}

	winnerUserID := rankings[0].UserID
	for _, r := range rankings {
		_, err := s.db.Exec(ctx, `
			UPDATE attempts SET validation_status = 'VALID', rank_in_match = $1 WHERE attempt_id = $2
		`, r.Rank, r.AttemptID)
		if err != nil {
			continue
		}
		_, err = s.db.Exec(ctx, `
			INSERT INTO results (result_id, score, duration_ms, rank_in_match, validated_at)
			VALUES ($1, NULL, $2, $3, NOW())
		`, r.AttemptID, r.DurationMs, r.Rank)
		if err != nil {
			continue
		}
	}

	var potTotal int64
	err = s.db.QueryRow(ctx, `SELECT pot_total_coins FROM matches WHERE match_id = $1`, matchID).Scan(&potTotal)
	if err != nil {
		return nil, err
	}

	fee := int64(float64(potTotal) * 0.001)
	if fee < 1 {
		fee = 1
	}
	payout := potTotal - fee

	_, err = s.db.Exec(ctx, `
		SELECT fn_apply_transaction($1, 'PAYOUT', $2, 'match', 'wallet', $3)
	`, winnerUserID, payout, matchID)
	if err != nil {
		return nil, fmt.Errorf("payout failed: %w", err)
	}

	_, err = s.db.Exec(ctx, `
		UPDATE wallets
		SET reserved_coins = GREATEST(reserved_coins - p.stake_coins, 0)
		FROM participations p
		WHERE p.match_id = $1 AND wallets.wallet_id = p.user_id
	`, matchID)
	if err != nil {
		return nil, err
	}

	_, err = s.db.Exec(ctx, `UPDATE matches SET status = 'FINISHED' WHERE match_id = $1`, matchID)
	if err != nil {
		return nil, err
	}

	for _, r := range rankings {
		_, err := s.db.Exec(ctx, `
			UPDATE profiles
			SET total_matches = total_matches + 1,
			    total_wins = total_wins + CASE WHEN $1 = 1 THEN 1 ELSE 0 END
			WHERE profile_id = $2
		`, r.Rank, r.UserID)
		if err != nil {
			continue
		}
	}

	var resultRanking []struct {
		Rank       int    `json:"rank"`
		UserID     string `json:"userId"`
		DurationMs int    `json:"durationMs"`
	}
	for _, r := range rankings {
		resultRanking = append(resultRanking, struct {
			Rank       int    `json:"rank"`
			UserID     string `json:"userId"`
			DurationMs int    `json:"durationMs"`
		}{
			Rank:       r.Rank,
			UserID:     r.UserID,
			DurationMs: r.DurationMs,
		})
	}

	return &models.MatchResults{
		MatchID:      matchID,
		Status:       "FINISHED",
		WinnerUserID: &winnerUserID,
		Ranking:      resultRanking,
	}, nil
}
