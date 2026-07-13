package config

import (
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	DatabaseURL      string
	RedisAddr        string
	JWTSecret        string
	JWTRefreshSecret string
	ServerPort       string
	GameServerPort   string
	StripeSecretKey  string
	Environment      string
}

func Load() *Config {
	_ = godotenv.Load("../../.env")
	return &Config{
		DatabaseURL:      getEnv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/tfatr?sslmode=disable"),
		RedisAddr:        getEnv("REDIS_ADDR", "localhost:6379"),
		JWTSecret:        getEnv("JWT_SECRET", "dev-secret-change-in-production"),
		JWTRefreshSecret: getEnv("JWT_REFRESH_SECRET", "dev-refresh-secret-change-in-production"),
		ServerPort:       getEnv("SERVER_PORT", "8080"),
		GameServerPort:   getEnv("GAME_SERVER_PORT", "8081"),
		StripeSecretKey:  getEnv("STRIPE_SECRET_KEY", "sk_test_"),
		Environment:      getEnv("ENV", "development"),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
