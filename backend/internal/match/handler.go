package match

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/thefastandtherich/backend/internal/models"
	"github.com/thefastandtherich/backend/internal/websocket"
)

type Handler struct {
	service *Service
	hub     *websocket.Hub
}

func NewHandler(service *Service, hub *websocket.Hub) *Handler {
	return &Handler{service: service, hub: hub}
}

func (h *Handler) GetGames(c *gin.Context) {
	rows, err := h.service.db.Query(c.Request.Context(), `
		SELECT g.game_id, g.name, g.category, g.current_version_id, g.status, gv.version_number
		FROM games g
		LEFT JOIN game_versions gv ON gv.version_id = g.current_version_id
		WHERE g.status = 'ACTIVE'
	`)
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
	defer rows.Close()

	var games []models.Game
	for rows.Next() {
		var g models.Game
		var versionID, versionNum string
		err := rows.Scan(&g.GameID, &g.Name, &g.Category, &versionID, &g.Status, &versionNum)
		if err != nil {
			continue
		}
		g.CurrentVersion = versionNum
		games = append(games, g)
	}

	c.JSON(http.StatusOK, games)
}

func (h *Handler) GetMatches(c *gin.Context) {
	categoryStr := c.Query("category")
	if categoryStr == "" {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Error: struct {
				Code    string `json:"code"`
				Message string `json:"message"`
				TraceID string `json:"traceId"`
			}{
				Code: "VALIDATION_ERROR", Message: "category required", TraceID: c.GetString("traceId"),
			},
		})
		return
	}

	category, err := strconv.Atoi(categoryStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Error: struct {
				Code    string `json:"code"`
				Message string `json:"message"`
				TraceID string `json:"traceId"`
			}{
				Code: "VALIDATION_ERROR", Message: "invalid category", TraceID: c.GetString("traceId"),
			},
		})
		return
	}

	matches, err := h.service.GetOpenMatches(c.Request.Context(), category)
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

	// Participant Count für jedes Match laden
	type matchWithCount struct {
		models.Match
		ParticipantCount int `json:"participantCount"`
	}
	var result []matchWithCount
	for _, m := range matches {
		count, _ := h.service.GetMatchParticipantCount(c.Request.Context(), m.MatchID)
		result = append(result, matchWithCount{
			Match:            m,
			ParticipantCount: count,
		})
	}

	c.JSON(http.StatusOK, result)
}

func (h *Handler) GetMatch(c *gin.Context) {
	matchID := c.Param("matchId")
	m, err := h.service.GetMatch(c.Request.Context(), matchID)
	if err != nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{
			Error: struct {
				Code    string `json:"code"`
				Message string `json:"message"`
				TraceID string `json:"traceId"`
			}{
				Code: "NOT_FOUND", Message: "Match nicht gefunden", TraceID: c.GetString("traceId"),
			},
		})
		return
	}
	c.JSON(http.StatusOK, m)
}

func (h *Handler) JoinMatch(c *gin.Context) {
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

	matchID := c.Param("matchId")
	var req models.JoinMatchRequest
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

	resp, err := h.service.JoinMatch(c.Request.Context(), userID, matchID, req.ClientDeviceInfo)
	if err != nil {
		errMsg := err.Error()
		if errMsg == "insufficient balance" {
			c.JSON(http.StatusPaymentRequired, models.ErrorResponse{
				Error: struct {
					Code    string `json:"code"`
					Message string `json:"message"`
					TraceID string `json:"traceId"`
				}{
					Code: "INSUFFICIENT_BALANCE", Message: "Nicht genügend Guthaben für diesen Einsatz", TraceID: c.GetString("traceId"),
				},
			})
			return
		}
		if errMsg == "match not open" {
			c.JSON(http.StatusConflict, models.ErrorResponse{
				Error: struct {
					Code    string `json:"code"`
					Message string `json:"message"`
					TraceID string `json:"traceId"`
				}{
					Code: "MATCH_NOT_OPEN", Message: "Match nicht mehr offen", TraceID: c.GetString("traceId"),
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

	// WebSocket Event: match.updated
	h.hub.PublishMatchEvent("match.updated", map[string]interface{}{
		"matchId":   matchID,
		"potTotal":  resp.MatchID, // wird im Frontend neu geladen
		"action":    "player_joined",
	})

	c.JSON(http.StatusOK, resp)
}

func (h *Handler) SubmitAttempt(c *gin.Context) {
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

	attemptID := c.Param("attemptId")
	var req models.AttemptSubmitRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, models.ErrorResponse{
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

	err := h.service.SubmitAttempt(c.Request.Context(), attemptID, req.InputPayload, req.ClientDurationMs)
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

	c.JSON(http.StatusAccepted, models.Attempt{
		AttemptID:        attemptID,
		ValidationStatus: "PENDING",
	})
}

func (h *Handler) GetMatchResults(c *gin.Context) {
	matchID := c.Param("matchId")
	var status string
	var winnerUserID *string

	err := h.service.db.QueryRow(c.Request.Context(), `
		SELECT status FROM matches WHERE match_id = $1
	`, matchID).Scan(&status)
	if err != nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{
			Error: struct {
				Code    string `json:"code"`
				Message string `json:"message"`
				TraceID string `json:"traceId"`
			}{
				Code: "NOT_FOUND", Message: "Match nicht gefunden", TraceID: c.GetString("traceId"),
			},
		})
		return
	}

	if status != "FINISHED" && status != "CANCELLED" {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Error: struct {
				Code    string `json:"code"`
				Message string `json:"message"`
				TraceID string `json:"traceId"`
			}{
				Code: "MATCH_NOT_FINISHED", Message: "Match noch nicht abgeschlossen", TraceID: c.GetString("traceId"),
			},
		})
		return
	}

	rows, err := h.service.db.Query(c.Request.Context(), `
		SELECT r.rank_in_match, p.user_id, r.duration_ms
		FROM results r
		JOIN attempts a ON a.attempt_id = r.result_id
		JOIN participations p ON p.participation_id = a.participation_id
		WHERE p.match_id = $1
		ORDER BY r.rank_in_match ASC
	`, matchID)
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
	defer rows.Close()

	var ranking []struct {
		Rank       int    `json:"rank"`
		UserID     string `json:"userId"`
		DurationMs int    `json:"durationMs"`
	}
	for rows.Next() {
		var r struct {
			Rank       int    `json:"rank"`
			UserID     string `json:"userId"`
			DurationMs int    `json:"durationMs"`
		}
		if err := rows.Scan(&r.Rank, &r.UserID, &r.DurationMs); err == nil {
			ranking = append(ranking, r)
			if r.Rank == 1 {
				uid := r.UserID
				winnerUserID = &uid
			}
		}
	}

	c.JSON(http.StatusOK, models.MatchResults{
		MatchID:      matchID,
		Status:       status,
		WinnerUserID: winnerUserID,
		Ranking:      ranking,
	})
}
