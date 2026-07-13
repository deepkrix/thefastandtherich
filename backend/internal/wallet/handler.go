package wallet

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/thefastandtherich/backend/internal/models"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) GetWallet(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{
			Error: struct {
				Code    string `json:"code"`
				Message string `json:"message"`
				TraceID string `json:"traceId"`
			}{
				Code: "UNAUTHORIZED", Message: "Nicht authentifiziert", TraceID: c.GetString("traceId"),
			},
		})
		return
	}

	wallet, err := h.service.GetWallet(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{
			Error: struct {
				Code    string `json:"code"`
				Message string `json:"message"`
				TraceID string `json:"traceId"`
			}{
				Code: "INTERNAL_ERROR", Message: err.Error(), TraceID: c.GetString("traceId"),
			},
		})
		return
	}

	c.JSON(http.StatusOK, wallet)
}

func (h *Handler) Deposit(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{
			Error: struct {
				Code    string `json:"code"`
				Message string `json:"message"`
				TraceID string `json:"traceId"`
			}{
				Code: "UNAUTHORIZED", Message: "Nicht authentifiziert", TraceID: c.GetString("traceId"),
			},
		})
		return
	}

	var req models.DepositRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Error: struct {
				Code    string `json:"code"`
				Message string `json:"message"`
				TraceID string `json:"traceId"`
			}{
				Code: "VALIDATION_ERROR", Message: err.Error(), TraceID: c.GetString("traceId"),
			},
		})
		return
	}

	txID, err := h.service.Deposit(c.Request.Context(), userID, req.AmountCoins, req.PaymentMethodID)
	if err != nil {
		// Stripe-Fehler -> 402 Payment Required
		if err.Error() == "kyc not verified" {
			c.JSON(http.StatusForbidden, models.ErrorResponse{
				Error: struct {
					Code    string `json:"code"`
					Message string `json:"message"`
					TraceID string `json:"traceId"`
				}{
					Code: "KYC_REQUIRED", Message: "KYC nicht abgeschlossen", TraceID: c.GetString("traceId"),
				},
			})
			return
		}
		c.JSON(http.StatusPaymentRequired, models.ErrorResponse{
			Error: struct {
				Code    string `json:"code"`
				Message string `json:"message"`
				TraceID string `json:"traceId"`
			}{
				Code: "PAYMENT_FAILED", Message: err.Error(), TraceID: c.GetString("traceId"),
			},
		})
		return
	}

	c.JSON(http.StatusAccepted, gin.H{
		"transactionId": txID,
		"status":        "PENDING",
	})
}

func (h *Handler) Withdraw(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{
			Error: struct {
				Code    string `json:"code"`
				Message string `json:"message"`
				TraceID string `json:"traceId"`
			}{
				Code: "UNAUTHORIZED", Message: "Nicht authentifiziert", TraceID: c.GetString("traceId"),
			},
		})
		return
	}

	var req models.WithdrawRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Error: struct {
				Code    string `json:"code"`
				Message string `json:"message"`
				TraceID string `json:"traceId"`
			}{
				Code: "VALIDATION_ERROR", Message: err.Error(), TraceID: c.GetString("traceId"),
			},
		})
		return
	}

	txID, err := h.service.Withdraw(c.Request.Context(), userID, req.AmountCoins, req.PayoutDestination)
	if err != nil {
		if err.Error() == "kyc not verified" {
			c.JSON(http.StatusForbidden, models.ErrorResponse{
				Error: struct {
					Code    string `json:"code"`
					Message string `json:"message"`
					TraceID string `json:"traceId"`
				}{
					Code: "KYC_REQUIRED", Message: "KYC nicht abgeschlossen", TraceID: c.GetString("traceId"),
				},
			})
			return
		}
		if err.Error() == "insufficient balance" {
			c.JSON(http.StatusPaymentRequired, models.ErrorResponse{
				Error: struct {
					Code    string `json:"code"`
					Message string `json:"message"`
					TraceID string `json:"traceId"`
				}{
					Code: "INSUFFICIENT_BALANCE", Message: "Unzureichendes Guthaben", TraceID: c.GetString("traceId"),
				},
			})
			return
		}
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{
			Error: struct {
				Code    string `json:"code"`
				Message string `json:"message"`
				TraceID string `json:"traceId"`
			}{
				Code: "INTERNAL_ERROR", Message: err.Error(), TraceID: c.GetString("traceId"),
			},
		})
		return
	}

	c.JSON(http.StatusAccepted, gin.H{
		"transactionId": txID,
		"status":        "PENDING",
	})
}

func (h *Handler) GetTransactions(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{
			Error: struct {
				Code    string `json:"code"`
				Message string `json:"message"`
				TraceID string `json:"traceId"`
			}{
				Code: "UNAUTHORIZED", Message: "Nicht authentifiziert", TraceID: c.GetString("traceId"),
			},
		})
		return
	}

	cursor := c.Query("cursor")
	limit, _ := strconv.Atoi(c.Query("limit"))
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	list, err := h.service.GetTransactions(c.Request.Context(), userID, cursor, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{
			Error: struct {
				Code    string `json:"code"`
				Message string `json:"message"`
				TraceID string `json:"traceId"`
			}{
				Code: "INTERNAL_ERROR", Message: err.Error(), TraceID: c.GetString("traceId"),
			},
		})
		return
	}

	c.JSON(http.StatusOK, list)
}
