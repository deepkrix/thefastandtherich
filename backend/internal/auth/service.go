package auth

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"math/rand"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/thefastandtherich/backend/internal/models"
	"github.com/thefastandtherich/backend/pkg/argon2"
)

type Service struct {
	db               *pgxpool.Pool
	jwtSecret        string
	jwtRefreshSecret string
}

func NewService(db *pgxpool.Pool, jwtSecret, jwtRefreshSecret string) *Service {
	return &Service{
		db:               db,
		jwtSecret:        jwtSecret,
		jwtRefreshSecret: jwtRefreshSecret,
	}
}

func (s *Service) Register(ctx context.Context, email, password string) (*models.User, error) {
	var exists bool
	err := s.db.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)", email).Scan(&exists)
	if err != nil {
		return nil, err
	}
	if exists {
		return nil, fmt.Errorf("email already registered")
	}

	hash, err := argon2.GenerateHash(password)
	if err != nil {
		return nil, err
	}

	userID := uuid.New().String()
	displayName := strings.Split(email, "@")[0]
	verificationCode := generateVerificationCode()

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		INSERT INTO users (user_id, email, password_hash, status, kyc_status, role)
		VALUES ($1, $2, $3, 'ACTIVE', 'NONE', 'PLAYER')
	`, userID, email, hash)
	if err != nil {
		return nil, err
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO wallets (wallet_id, balance_coins, reserved_coins, currency_rate, status)
		VALUES ($1, 0, 0, 0.01, 'ACTIVE')
	`, userID)
	if err != nil {
		return nil, err
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO profiles (profile_id, display_name, level, total_matches, total_wins)
		VALUES ($1, $2, 1, 0, 0)
	`, userID, displayName)
	if err != nil {
		return nil, err
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO verification_codes (user_id, code, expires_at)
		VALUES ($1, $2, $3)
	`, userID, verificationCode, time.Now().Add(24*time.Hour))
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}

	// MVP: Code in Logs ausgeben statt E-Mail zu senden
	fmt.Printf("[MVP-EMAIL] Verification code for %s: %s\n", email, verificationCode)

	return &models.User{
		UserID:    userID,
		Email:     email,
		Status:    "ACTIVE",
		KycStatus: "NONE",
		Role:      "PLAYER",
		CreatedAt: time.Now(),
	}, nil
}

func (s *Service) Login(ctx context.Context, email, password string) (*models.TokenResponse, error) {
	var user models.User
	var hash string
	err := s.db.QueryRow(ctx, `
		SELECT user_id, email, password_hash, status, kyc_status, role, created_at
		FROM users WHERE email = $1
	`, email).Scan(&user.UserID, &user.Email, &hash, &user.Status, &user.KycStatus, &user.Role, &user.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("invalid credentials")
	}

	valid, err := argon2.CompareHash(password, hash)
	if err != nil || !valid {
		return nil, fmt.Errorf("invalid credentials")
	}

	var verified bool
	err = s.db.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM verification_codes
			WHERE user_id = $1 AND used_at IS NOT NULL
		)
	`, user.UserID).Scan(&verified)
	if err != nil {
		return nil, err
	}
	if !verified {
		return nil, fmt.Errorf("email not verified")
	}

	accessToken, err := GenerateAccessToken(user.UserID, user.Email, user.Role, s.jwtSecret, 15*time.Minute)
	if err != nil {
		return nil, err
	}

	tokenID := uuid.New().String()
	refreshToken, err := GenerateRefreshToken(user.UserID, tokenID, s.jwtRefreshSecret, 7*24*time.Hour)
	if err != nil {
		return nil, err
	}

	tokenHash := hashToken(refreshToken)
	_, err = s.db.Exec(ctx, `
		INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
		VALUES ($1, $2, $3)
	`, user.UserID, tokenHash, time.Now().Add(7*24*time.Hour))
	if err != nil {
		return nil, err
	}

	return &models.TokenResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    900,
	}, nil
}

func (s *Service) Verify(ctx context.Context, userID, code string) error {
	var codeID string
	err := s.db.QueryRow(ctx, `
		SELECT code_id FROM verification_codes
		WHERE user_id = $1 AND code = $2 AND used_at IS NULL AND expires_at > NOW()
	`, userID, code).Scan(&codeID)
	if err != nil {
		return fmt.Errorf("invalid or expired code")
	}

	_, err = s.db.Exec(ctx, `
		UPDATE verification_codes SET used_at = NOW() WHERE code_id = $1
	`, codeID)
	return err
}

func (s *Service) Refresh(ctx context.Context, refreshToken string) (*models.TokenResponse, error) {
	claims, err := ValidateRefreshToken(refreshToken, s.jwtRefreshSecret)
	if err != nil {
		return nil, fmt.Errorf("invalid refresh token")
	}

	tokenHash := hashToken(refreshToken)
	var userID, email, role string
	err = s.db.QueryRow(ctx, `
		SELECT rt.user_id, u.email, u.role
		FROM refresh_tokens rt
		JOIN users u ON u.user_id = rt.user_id
		WHERE rt.token_hash = $1 AND rt.revoked_at IS NULL AND rt.expires_at > NOW()
	`, tokenHash).Scan(&userID, &email, &role)
	if err != nil {
		return nil, fmt.Errorf("invalid refresh token")
	}

	if userID != claims.UserID {
		return nil, fmt.Errorf("token mismatch")
	}

	_, err = s.db.Exec(ctx, `
		UPDATE refresh_tokens SET revoked_at = NOW() WHERE token_hash = $1
	`, tokenHash)
	if err != nil {
		return nil, err
	}

	accessToken, err := GenerateAccessToken(userID, email, role, s.jwtSecret, 15*time.Minute)
	if err != nil {
		return nil, err
	}

	newTokenID := uuid.New().String()
	newRefreshToken, err := GenerateRefreshToken(userID, newTokenID, s.jwtRefreshSecret, 7*24*time.Hour)
	if err != nil {
		return nil, err
	}

	newTokenHash := hashToken(newRefreshToken)
	_, err = s.db.Exec(ctx, `
		INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
		VALUES ($1, $2, $3)
	`, userID, newTokenHash, time.Now().Add(7*24*time.Hour))
	if err != nil {
		return nil, err
	}

	return &models.TokenResponse{
		AccessToken:  accessToken,
		RefreshToken: newRefreshToken,
		ExpiresIn:    900,
	}, nil
}

func (s *Service) Logout(ctx context.Context, userID string) error {
	_, err := s.db.Exec(ctx, `
		UPDATE refresh_tokens SET revoked_at = NOW()
		WHERE user_id = $1 AND revoked_at IS NULL
	`, userID)
	return err
}

func generateVerificationCode() string {
	return fmt.Sprintf("%06d", rand.Intn(1000000))
}

func hashToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}
