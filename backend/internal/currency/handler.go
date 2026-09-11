package currency

import "github.com/gin-gonic/gin"

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) GetRate(c *gin.Context) {
	rate, err := h.service.GetRate(c.Query("from"), c.Query("to"))
	if err != nil {
		c.JSON(503, gin.H{"error": "exchange rates are temporarily unavailable"})
		return
	}
	c.JSON(200, rate)
}
