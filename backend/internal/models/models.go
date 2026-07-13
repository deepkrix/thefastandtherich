package models

import "time"

type User struct {
	UserID    string    `json:"userId"`
	Email     string    `json:"email"`
	Status    string    `json:"status"`
	KycStatus string    `json:"kycStatus"`
	Role      string    `json:"role"`
	CreatedAt time.Time `json:"createdAt"`
}

type TokenResponse struct {
	AccessToken  string `json:"accessToken"`
	RefreshToken string `json:"refreshToken"`
	ExpiresIn    int    `json:"expiresIn"`
}

type ErrorResponse struct {
	Error struct {
		Code    string `json:"code"`
		Message string `json:"message"`
		TraceID string `json:"traceId"`
	} `json:"error"`
}

type Profile struct {
	ProfileID    string `json:"profileId"`
	DisplayName  string `json:"displayName"`
	AvatarURL    string `json:"avatarUrl"`
	Title        string `json:"title"`
	Level        int    `json:"level"`
	TotalMatches int    `json:"totalMatches"`
	TotalWins    int    `json:"totalWins"`
}

type ProfileUpdateRequest struct {
	DisplayName string `json:"displayName"`
	AvatarURL   string `json:"avatarUrl"`
}

type ProfileStats struct {
	TotalMatches int     `json:"totalMatches"`
	TotalWins    int     `json:"totalWins"`
	WinRate      float64 `json:"winRate"`
	Level        int     `json:"level"`
}

type Wallet struct {
	WalletID      string  `json:"walletId"`
	BalanceCoins  int64   `json:"balanceCoins"`
	ReservedCoins int64   `json:"reservedCoins"`
	CurrencyRate  float64 `json:"currencyRate"`
	Status        string  `json:"status"`
}

type DepositRequest struct {
	AmountCoins     int    `json:"amountCoins"`
	PaymentMethodID string `json:"paymentMethodId"`
}

type WithdrawRequest struct {
	AmountCoins       int    `json:"amountCoins"`
	PayoutDestination string `json:"payoutDestination"`
}

type Transaction struct {
	TransactionID string    `json:"transactionId"`
	Type          string    `json:"type"`
	AmountCoins   int64     `json:"amountCoins"`
	BalanceAfter  int64     `json:"balanceAfter"`
	ReferenceID   *string   `json:"referenceId"`
	CreatedAt     time.Time `json:"createdAt"`
}

type Game struct {
	GameID         string `json:"gameId"`
	Name           string `json:"name"`
	Category       string `json:"category"`
	CurrentVersion string `json:"currentVersion"`
	Status         string `json:"status"`
}

type Match struct {
	MatchID         string    `json:"matchId"`
	GameID          string    `json:"gameId"`
	ArenaID         string    `json:"arenaId"`
	StakeCoins      int       `json:"stakeCoins"`
	Status          string    `json:"status"`
	MaxParticipants int       `json:"maxParticipants"`
	MinParticipants int       `json:"minParticipants"`
	PotTotalCoins   int64     `json:"potTotalCoins"`
	OpensAt         time.Time `json:"opensAt"`
	ClosesAt        time.Time `json:"closesAt"`
}

type ClientDeviceInfo struct {
	Platform         string `json:"platform"`
	AttestationToken string `json:"attestationToken"`
}

type JoinMatchRequest struct {
	UserID           string           `json:"userId"`
	ClientDeviceInfo ClientDeviceInfo `json:"clientDeviceInfo"`
}

type GameConfig struct {
	GameID  string `json:"gameId"`
	Version string `json:"version"`
	Seed    string `json:"seed"`
}

type JoinMatchResponse struct {
	MatchID         string     `json:"matchId"`
	AttemptID       string     `json:"attemptId"`
	GameConfig      GameConfig `json:"gameConfig"`
	ServerTimestamp time.Time  `json:"serverTimestamp"`
	SecurityToken   string     `json:"securityToken"`
}

type AttemptSubmitRequest struct {
	InputPayload     string `json:"inputPayload"`
	ClientDurationMs int    `json:"clientDurationMs"`
}

type Attempt struct {
	AttemptID        string `json:"attemptId"`
	ValidationStatus string `json:"validationStatus"`
	DurationMs       *int   `json:"durationMs"`
	RankInMatch      *int   `json:"rankInMatch"`
}

type MatchResults struct {
	MatchID      string `json:"matchId"`
	Status       string `json:"status"`
	WinnerUserID *string `json:"winnerUserId"`
	Ranking      []struct {
		Rank       int    `json:"rank"`
		UserID     string `json:"userId"`
		DurationMs int    `json:"durationMs"`
	} `json:"ranking"`
}

type RankingEntry struct {
	Rank        int    `json:"rank"`
	UserID      string `json:"userId"`
	DisplayName string `json:"displayName"`
	RankValue   int    `json:"rankValue"`
}

type Event struct {
	EventID  string    `json:"eventId"`
	Type     string    `json:"type"`
	StartsAt time.Time `json:"startsAt"`
	EndsAt   time.Time `json:"endsAt"`
}

type AuditLogEntry struct {
	LogID      string    `json:"logId"`
	ActorID    *string   `json:"actorId"`
	ActionType string    `json:"actionType"`
	TargetType *string   `json:"targetType"`
	TargetID   *string   `json:"targetId"`
	CreatedAt  time.Time `json:"createdAt"`
}

type SuspendUserRequest struct {
	Reason       string `json:"reason"`
	DurationDays *int   `json:"durationDays"`
}


type TransactionList struct {
	Items      []Transaction `json:"items"`
	NextCursor *string       `json:"nextCursor"`
}
