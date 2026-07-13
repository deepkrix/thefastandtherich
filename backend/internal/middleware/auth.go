package middleware

import (
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/thefastandtherich/backend/internal/auth"
	"github.com/thefastandtherich/backend/internal/models"
)

func Auth(jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, models.ErrorResponse{
				Error: struct {
					Code    string `json:"code"`
					Message string `json:"message"`
					TraceID string `json:"traceId"`
				}{
					Code:    "UNAUTHORIZED", Message: "Authorization header required", TraceID: c.GetString("traceId"),
				},
			})
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, models.ErrorResponse{
				Error: struct {
					Code    string `json:"code"`
					Message string `json:"message"`
					TraceID string `json:"traceId"`
				}{
					Code:    "UNAUTHORIZED", Message: "Invalid authorization header format", TraceID: c.GetString("traceId"),
				},
			})
			return
		}

		claims, err := auth.ValidateAccessToken(parts[1], jwtSecret)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, models.ErrorResponse{
				Error: struct {
					Code    string `json:"code"`
					Message string `json:"message"`
					TraceID string `json:"traceId"`
				}{
					Code:    "UNAUTHORIZED", Message: "Invalid or expired token", TraceID: c.GetString("traceId"),
				},
			})
			return
		}

		c.Set("userID", claims.UserID)
		c.Set("email", claims.Email)
		c.Set("role", claims.Role)
		c.Next()
	}
}

func TraceID() gin.HandlerFunc {
	return func(c *gin.Context) {
		traceID := "req_" + time.Now().Format("20060102150405") + "_" + randomString(8)
		c.Set("traceId", traceID)
		c.Next()
	}
}

func randomString(n int) string {
	const letters = "abcdefghijklmnopqrstuvwxyz0123456789"
	b := make([]byte, n)
	for i := range b {
		b[i] = letters[time.Now().UnixNano()%int64(len(letters))]
	}
	return string(b)
}
