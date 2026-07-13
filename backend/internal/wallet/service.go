package wallet

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stripe/stripe-go/v76"
	"github.com/stripe/stripe-go/v76/paymentintent"

	"github.com/thefastandtherich/backend/internal/models"
)

type Service struct {
	db            *pgxpool.Pool
	stripeKey     string
	currencyRate  float64
}

func NewService(db *pgxpool.Pool, stripeKey string) *Service {
	stripe.Key = stripeKey
	return &Service{
		db:           db,
		stripeKey:    stripeKey,
		currencyRate: 0.01, // 1 Coin = 0.01 € (SRS Kap. 7.2)
	}
}

func (s *Service) GetWallet(ctx context.Context, userID string) (*models.Wallet, error) {
	var w models.Wallet
	err := s.db.QueryRow(ctx, `
		SELECT wallet_id, balance_coins, reserved_coins, currency_rate, status
		FROM wallets WHERE wallet_id = $1
	`, userID).Scan(&w.WalletID, &w.BalanceCoins, &w.ReservedCoins, &w.CurrencyRate, &w.Status)
	if err != nil {
		return nil, err
	}
	return &w, nil
}

func (s *Service) Deposit(ctx context.Context, userID string, amountCoins int, paymentMethodID string) (string, error) {
	// 1. Stripe PaymentIntent im Testmodus erstellen
	amountCents := int64(amountCoins) * 100 // 1 Coin = 0.01 € = 1 Cent... warte, 1 Coin = 0.01 €, also amountCoins * 0.01 € = amountCoins Cent
	// Korrektur: 1 Coin = 0.01 € = 1 Cent. Also 100 Coins = 1 € = 100 Cent.
	// amountCoins * 1 Cent = amountCoins Cent.
	amountCents = int64(amountCoins) // 1 Coin = 1 Cent im Stripe-Test (vereinfacht für Testmodus)

	params := &stripe.PaymentIntentParams{
		Amount:   stripe.Int64(amountCents),
		Currency: stripe.String(string(stripe.CurrencyEUR)),
		PaymentMethod: stripe.String(paymentMethodID),
		Confirm:       stripe.Bool(true),
		OffSession:    stripe.Bool(true),
	}

	pi, err := paymentintent.New(params)
	if err != nil {
		stripeErr, ok := err.(*stripe.Error)
		if ok {
			return "", fmt.Errorf("stripe error: %s", stripeErr.Msg)
		}
		return "", fmt.Errorf("stripe payment failed: %w", err)
	}

	if pi.Status != stripe.PaymentIntentStatusSucceeded {
		return "", fmt.Errorf("payment not succeeded: %s", pi.Status)
	}

	// 2. Ledger-Buchung via fn_apply_transaction (SRS Core Decision)
	var txID string
	err = s.db.QueryRow(ctx, `
		SELECT fn_apply_transaction($1, $2, $3, $4, $5, $6)
	`, userID, "DEPOSIT", amountCoins, "stripe", "wallet", pi.ID).Scan(&txID)
	if err != nil {
		return "", fmt.Errorf("ledger booking failed: %w", err)
	}

	return txID, nil
}

func (s *Service) Withdraw(ctx context.Context, userID string, amountCoins int, payoutDestination string) (string, error) {
	// KYC-Check
	var kycStatus string
	err := s.db.QueryRow(ctx, `SELECT kyc_status FROM users WHERE user_id = $1`, userID).Scan(&kycStatus)
	if err != nil {
		return "", err
	}
	if kycStatus != "VERIFIED" {
		return "", fmt.Errorf("kyc not verified")
	}

	// Guthaben-Check (fn_apply_transaction macht das auch, aber früher fail = besser UX)
	var balance int64
	err = s.db.QueryRow(ctx, `SELECT balance_coins FROM wallets WHERE wallet_id = $1`, userID).Scan(&balance)
	if err != nil {
		return "", err
	}
	if balance < int64(amountCoins) {
		return "", fmt.Errorf("insufficient balance")
	}

	// Ledger-Buchung (negativ für Abzug)
	var txID string
	err = s.db.QueryRow(ctx, `
		SELECT fn_apply_transaction($1, $2, $3, $4, $5, NULL)
	`, userID, "WITHDRAWAL", -amountCoins, "wallet", payoutDestination).Scan(&txID)
	if err != nil {
		return "", fmt.Errorf("ledger booking failed: %w", err)
	}

	return txID, nil
}

func (s *Service) GetTransactions(ctx context.Context, userID string, cursor string, limit int) (*models.TransactionList, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	var rows pgx.Rows
	var err error

	if cursor != "" {
		// Cursor-basierte Pagination (created_at < cursor)
		cursorTime, _ := time.Parse(time.RFC3339Nano, cursor)
		rows, err = s.db.Query(ctx, `
			SELECT transaction_id, type, amount_coins, balance_after, reference_id, created_at
			FROM transactions
			WHERE wallet_id = $1 AND created_at < $2
			ORDER BY created_at DESC
			LIMIT $3
		`, userID, cursorTime, limit)
	} else {
		rows, err = s.db.Query(ctx, `
			SELECT transaction_id, type, amount_coins, balance_after, reference_id, created_at
			FROM transactions
			WHERE wallet_id = $1
			ORDER BY created_at DESC
			LIMIT $2
		`, userID, limit)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []models.Transaction
	var lastCreatedAt time.Time
	for rows.Next() {
		var t models.Transaction
		var refID *string
		err := rows.Scan(&t.TransactionID, &t.Type, &t.AmountCoins, &t.BalanceAfter, &refID, &t.CreatedAt)
		if err != nil {
			return nil, err
		}
		t.ReferenceID = refID
		items = append(items, t)
		lastCreatedAt = t.CreatedAt
	}

	var nextCursor *string
	if len(items) == limit {
		c := lastCreatedAt.Format(time.RFC3339Nano)
		nextCursor = &c
	}

	return &models.TransactionList{
		Items:      items,
		NextCursor: nextCursor,
	}, nil
}
