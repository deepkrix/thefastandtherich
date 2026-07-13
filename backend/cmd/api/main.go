package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/thefastandtherich/backend/internal/auth"
	"github.com/thefastandtherich/backend/internal/config"
	"github.com/thefastandtherich/backend/internal/match"
	"github.com/thefastandtherich/backend/internal/middleware"
	"github.com/thefastandtherich/backend/internal/wallet"
	"github.com/thefastandtherich/backend/internal/websocket"
)

func main() {
	cfg := config.Load()

	dbPool, err := pgxpool.New(context.Background(), cfg.DatabaseURL)
	if err != nil {
		log.Fatal("Unable to connect to database:", err)
	}
	defer dbPool.Close()

	redisClient := redis.NewClient(&redis.Options{
		Addr: cfg.RedisAddr,
	})
	if err := redisClient.Ping(context.Background()).Err(); err != nil {
		log.Fatal("Unable to connect to Redis:", err)
	}

	authService := auth.NewService(dbPool, cfg.JWTSecret, cfg.JWTRefreshSecret)
	authHandler := auth.NewHandler(authService)

	walletService := wallet.NewService(dbPool, cfg.StripeSecretKey)
	walletHandler := wallet.NewHandler(walletService)

	wsHub := websocket.NewHub(redisClient)
	go wsHub.Run()
	wsHandler := websocket.NewHandler(wsHub, cfg.JWTSecret)

	matchService := match.NewService(dbPool)
	matchHandler := match.NewHandler(matchService, wsHub)

	r := gin.Default()
	r.Use(middleware.CORS())
	r.Use(middleware.TraceID())

	authPublic := r.Group("/v1/auth")
	{
		authPublic.POST("/register", authHandler.Register)
		authPublic.POST("/login", authHandler.Login)
		authPublic.POST("/verify", authHandler.Verify)
		authPublic.POST("/refresh", authHandler.Refresh)
	}

	authProtected := r.Group("/v1/auth")
	authProtected.Use(middleware.Auth(cfg.JWTSecret))
	{
		authProtected.POST("/logout", authHandler.Logout)
	}

	walletGroup := r.Group("/v1/wallet")
	walletGroup.Use(middleware.Auth(cfg.JWTSecret))
	{
		walletGroup.GET("", walletHandler.GetWallet)
		walletGroup.POST("/deposit", walletHandler.Deposit)
		walletGroup.POST("/withdraw", walletHandler.Withdraw)
		walletGroup.GET("/transactions", walletHandler.GetTransactions)
	}

	gameGroup := r.Group("/v1")
	gameGroup.Use(middleware.Auth(cfg.JWTSecret))
	{
		gameGroup.GET("/games", matchHandler.GetGames)
		gameGroup.GET("/matches", matchHandler.GetMatches)
		gameGroup.GET("/matches/:matchId", matchHandler.GetMatch)
		gameGroup.POST("/matches/:matchId/join", matchHandler.JoinMatch)
		gameGroup.POST("/matches/:matchId/attempts/:attemptId/submit", matchHandler.SubmitAttempt)
		gameGroup.GET("/matches/:matchId/results", matchHandler.GetMatchResults)
	}

	r.GET("/v1/ws", wsHandler.HandleWebSocket)

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "service": "api-server"})
	})

	seedGames(dbPool)

	srv := &http.Server{
		Addr:    ":" + cfg.ServerPort,
		Handler: r,
	}

	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %s\n", err)
		}
	}()
	log.Printf("API-Server running on :%s", cfg.ServerPort)

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatal("Server forced to shutdown:", err)
	}
	log.Println("Server exiting")
}

func seedGames(db *pgxpool.Pool) {
	ctx := context.Background()
	var count int
	err := db.QueryRow(ctx, "SELECT COUNT(*) FROM games").Scan(&count)
	if err != nil || count > 0 {
		return
	}

	games := []struct {
		name     string
		category string
	}{
		{"Reaction Tap", "reflex"},
		{"Precision Timing", "timing"},
		{"Sequence Memory", "memory"},
		{"Aim & Click", "aim"},
		{"Math Sprint", "math"},
	}

	for _, g := range games {
		var gameID string
		err := db.QueryRow(ctx, `
			INSERT INTO games (name, category, status)
			VALUES ($1, $2, 'ACTIVE')
			RETURNING game_id
		`, g.name, g.category).Scan(&gameID)
		if err != nil {
			log.Printf("Failed to seed game %s: %v", g.name, err)
			continue
		}

		var versionID string
		err = db.QueryRow(ctx, `
			INSERT INTO game_versions (game_id, version_number, ruleset)
			VALUES ($1, '1.0.0', '{}')
			RETURNING version_id
		`, gameID).Scan(&versionID)
		if err != nil {
			log.Printf("Failed to seed version for %s: %v", g.name, err)
			continue
		}

		_, err = db.Exec(ctx, `UPDATE games SET current_version_id = $1 WHERE game_id = $2`, versionID, gameID)
		if err != nil {
			log.Printf("Failed to update current_version for %s: %v", g.name, err)
		}
	}
	log.Println("Games seeded successfully")
}
