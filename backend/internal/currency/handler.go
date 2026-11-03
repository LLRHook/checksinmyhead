package currency

import (
	"context"
	"github.com/gin-gonic/gin"
	"net/http"
	"time"
)

type Rate struct {
	From      string    `json:"from"`
	To        string    `json:"to"`
	Value     float64   `json:"rate"`
	Source    string    `json:"source"`
	UpdatedAt time.Time `json:"updated_at"`
}

type Handler struct{ provider Provider }

func NewHandler(provider Provider) *Handler {
	if provider == nil {
		panic("currency provider is required")
	}
	return &Handler{provider: provider}
}
func (h *Handler) GetRate(c *gin.Context) {
	from, to := Normalize(c.Query("from")), Normalize(c.Query("to"))
	if !ValidCode(from) || !ValidCode(to) {
		c.JSON(503, gin.H{"error": "exchange rates are temporarily unavailable"})
		return
	}
	ctx, cancel := context.WithTimeout(c.Request.Context(), OperationTimeout)
	defer cancel()
	if from == to {
		c.JSON(200, Rate{From: from, To: to, Value: 1, Source: "same_currency", UpdatedAt: time.Now().UTC()})
		return
	}
	quote, err := h.provider.Latest(ctx, from, to)
	if err == nil {
		err = ValidateQuote(quote, from, to, time.Now())
	}
	if err != nil {
		WriteRetryAfter(c, err)
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "exchange rates are temporarily unavailable"})
		return
	}
	day, _ := time.Parse(time.DateOnly, quote.Date)
	c.JSON(200, Rate{From: from, To: to, Value: quote.Rate, Source: quote.Source, UpdatedAt: day})
}
