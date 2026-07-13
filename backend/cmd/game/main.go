package main

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/thefastandtherich/backend/internal/config"
)

func main() {
	cfg := config.Load()

	r := gin.Default()
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"service": "game-server", "status": "ok"})
	})

	port := cfg.GameServerPort
	if port == "" {
		port = "8081"
	}

	log.Printf("Game server starting on :%s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatal(err)
	}
}
