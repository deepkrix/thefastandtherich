package auth

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/thefastandtherich/backend/internal/models"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func newErrorResponse(code, message, traceID string) models.ErrorResponse {
	return models.ErrorResponse{
		Error: struct {
			Code    string `json:"code"`
			Message string `json:"message"`
			TraceID string `json:"traceId"`
		}{
			Code:    code,
			Message: message,
			TraceID: traceID,
		},
	}
}

func (h *Handler) Register(c *gin.Context) {
	var req struct {
		Email    string `json:"email" binding:"required,email"`
		Password string `json:"password" binding:"required,min=10"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, newErrorResponse("VALIDATION_ERROR", err.Error(), c.GetString("traceId")))
		return
	}

	user, err := h.service.Register(c.Request.Context(), req.Email, req.Password)
	if err != nil {
		if err.Error() == "email already registered" {
			c.JSON(http.StatusConflict, newErrorResponse("EMAIL_EXISTS", "E-Mail bereits registriert", c.GetString("traceId")))
			return
		}
		c.JSON(http.StatusInternalServerError, newErrorResponse("INTERNAL_ERROR", err.Error(), c.GetString("traceId")))
		return
	}

	c.JSON(http.StatusCreated, user)
}

func (h *Handler) Login(c *gin.Context) {
	var req struct {
		Email    string `json:"email" binding:"required,email"`
		Password string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, newErrorResponse("VALIDATION_ERROR", err.Error(), c.GetString("traceId")))
		return
	}

	tokens, err := h.service.Login(c.Request.Context(), req.Email, req.Password)
	if err != nil {
		msg := err.Error()
		if strings.Contains(msg, "not verified") {
			c.JSON(http.StatusUnauthorized, newErrorResponse("EMAIL_NOT_VERIFIED", "E-Mail noch nicht verifiziert. Bitte gib den Code aus der Bestätigungs-E-Mail ein.", c.GetString("traceId")))
			return
		}
		c.JSON(http.StatusUnauthorized, newErrorResponse("INVALID_CREDENTIALS", "Ungültige Zugangsdaten", c.GetString("traceId")))
		return
	}

	c.JSON(http.StatusOK, tokens)
}

func (h *Handler) Verify(c *gin.Context) {
	var req struct {
		UserID           string `json:"userId" binding:"required"`
		VerificationCode string `json:"verificationCode" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, newErrorResponse("VALIDATION_ERROR", err.Error(), c.GetString("traceId")))
		return
	}

	err := h.service.Verify(c.Request.Context(), req.UserID, req.VerificationCode)
	if err != nil {
		c.JSON(http.StatusBadRequest, newErrorResponse("INVALID_CODE", "Ungültiger oder abgelaufener Code", c.GetString("traceId")))
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "verified"})
}

func (h *Handler) Refresh(c *gin.Context) {
	var req struct {
		RefreshToken string `json:"refreshToken" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, newErrorResponse("VALIDATION_ERROR", err.Error(), c.GetString("traceId")))
		return
	}

	tokens, err := h.service.Refresh(c.Request.Context(), req.RefreshToken)
	if err != nil {
		c.JSON(http.StatusUnauthorized, newErrorResponse("INVALID_REFRESH_TOKEN", "Refresh-Token ungültig oder abgelaufen", c.GetString("traceId")))
		return
	}

	c.JSON(http.StatusOK, tokens)
}

func (h *Handler) Logout(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, newErrorResponse("UNAUTHORIZED", "Nicht authentifiziert", c.GetString("traceId")))
		return
	}

	err := h.service.Logout(c.Request.Context(), userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, newErrorResponse("INTERNAL_ERROR", err.Error(), c.GetString("traceId")))
		return
	}

	c.Status(http.StatusNoContent)
}
