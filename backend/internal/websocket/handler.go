package websocket

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/thefastandtherich/backend/internal/auth"
)

type Handler struct {
	hub       *Hub
	jwtSecret string
}

func NewHandler(hub *Hub, jwtSecret string) *Handler {
	return &Handler{hub: hub, jwtSecret: jwtSecret}
}

func (h *Handler) HandleWebSocket(c *gin.Context) {
	// JWT aus Query-Parameter oder Header extrahieren (WebSocket kann keine Custom Headers)
	token := c.Query("token")
	if token == "" {
		authHeader := c.GetHeader("Authorization")
		if strings.HasPrefix(authHeader, "Bearer ") {
			token = strings.TrimPrefix(authHeader, "Bearer ")
		}
	}

	if token == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "token required"})
		return
	}

	claims, err := auth.ValidateAccessToken(token, h.jwtSecret)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
		return
	}

	ServeWs(h.hub, c.Writer, c.Request, claims.UserID)
}
